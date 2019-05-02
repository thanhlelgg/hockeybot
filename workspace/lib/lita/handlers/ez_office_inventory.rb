# lita-jira plugin
module Lita
  # Because we can.
  module Handlers
    # Main handler
    # rubocop:disable Metrics/ClassLength
    class EzOfficeInventory < Handler
      namespace 'common'

      ITEM_PATTERN                 = /(?<item>.+)/
      EMAIL_REGEX                  = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
      CHECKOUT_STATE_EZ            = 'checked_out'
      ASSET_PATTERN                = /(?<asset>[0-9]{1,5}+)/
      EMAIL_PATTERN                = /(?<email>[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+)/
      LOCATION_PATTERN             = /(?<location>[a-zA-Z |]+)/
      MAX_EZ_RESULTS_PAGE_SIZE     = 25

      route(%r{.*ezsearch\s#{ITEM_PATTERN}}i,
        :ez_search_assets,
        command: false,
        help: {t('help.ez_search_assets.syntax') => t('help.ez_search_assets.desc')}
      )

      route(%r{.*ezcheckout\s#{ASSET_PATTERN}\s#{EMAIL_PATTERN}$}i,
            :ez_checkout_asset_no_location,
            command: false,
            help: {t('help.ez_checkout_asset_no_location.syntax') => t('help.ez_checkout_asset_no_location.desc')}
      )

      route(%r{.*ezcheckout\s#{ASSET_PATTERN}\s#{EMAIL_PATTERN}\s#{LOCATION_PATTERN}}i,
        :ez_checkout_asset,
        command: false,
        help: {t('help.ez_checkout_asset.syntax') => t('help.ez_checkout_asset.desc')}
      )

      route(%r{.*ezfilter\s#{ITEM_PATTERN}}i,
            :filtered_ez_assets_list,
            command: false,
            help: {t('help.ez_filter.syntax') => t('help.ez_filter.desc')}
      )

      def filtered_ez_assets_list(response)
        filter_status = response.match_data['item'].strip
        response.reply("Finding devices matching *#{filter_status}*...")
        assets = get_assets_by_filter("#{config.jira.ez_office_site}/filter.api?status=#{filter_status}")
        if assets.length == 0
          response.reply("No devices found from the filter.")
          return
        else
          result = ""
          assets.each do |asset|
            result += get_asset_result(asset)
            if filter_status == 'overdue'
              if get_num_overdue_days(asset).to_i == 0
                num_overdue_days_response = " Number of days overdue: Less than a day."
              else
                num_overdue_days_response = " Number of days overdue: " + "#{get_num_overdue_days(asset)}."
              end
              result += num_overdue_days_response
            end
          end
          response.reply("#{result}\n#{assets.length} devices were found.")
        end
      end

      def ez_search_assets(response)
        begin
          item = response.match_data['item'].strip
          result = ""

          if is_email_address(item)
            ez_assets_user_list(response)
            return
          end

          response.reply("Finding devices matching *#{item}*...")
          result = get_assets_by_search(item)

          if result != ""
            response.reply("#{result}")
          else
            response.reply("No devices found matching your query.")
          end
        rescue => ex
          response.reply("#{ex}")
        end
      end

      def ez_assets_user_list(response)
        user_email = response.match_data['item'].strip
        member = find_member_by_email(user_email)
        result = ""
        if member == ""
          response.reply("User was not found in EzOffice.")
          return
        else
          response.reply("Finding all devices that are checked out for *#{member['full_name']}*...")
          assets = get_assets_by_member_id(member['id'])
          assets.each do |asset|
            result += get_asset_result(asset)
          end
          response.reply("#{result}\n#{assets.length} devices are checked out by #{member['full_name']}.")
        end
      end

      def ez_checkout_asset_no_location(response)
        ez_checkout_asset(response, location: "San Francisco")
      end

      def ez_checkout_asset(response, location: nil)
        asset_num = response.match_data['asset'].strip
        user_email = response.match_data['email'].strip

        if location
          location_id = find_location_id(location)
        else
          location = response.match_data['location'].strip
          location_id = find_location_id(location)
        end

        if location_id == ""
          response.reply(t('ez_checkout_asset.location_not_found', location_name: location))
          return
        end

        asset_result = get_data_from_ez("#{config.jira.ez_office_site}/#{asset_num}.api")
        if asset_result["asset"]
          if asset_result['asset']['state'] == CHECKOUT_STATE_EZ
            result = (t('ez_checkout_asset.asset_checked_out',
                        ez_url: config.jira.ez_office_site,
                        asset_num: asset_result['asset']['sequence_num'],
                        asset_name: asset_result['asset']['name'],
                        user_name: asset_result['asset']['assigned_to_user_name']))

          else
            user = find_member_by_email(user_email)
            if user == ""
              result = t('ez_checkout_asset.user_not_found')
            else
              user_id = user['id']
              comments = t('ez_checkout_asset.comment', asset_name: asset_result['asset']['name'],
                            user_email: user_email)
              checkout_result = checkout_asset_to_user(user_id, location_id, asset_num, comments)
              if checkout_result.response_code == 200
                asset = get_data_from_ez("#{config.jira.ez_office_site}/#{asset_num}.api")['asset']
                result = t('ez_checkout_asset.checkout_result',
                           ez_url: config.jira.ez_office_site,
                           asset_name: asset['name'],
                           user_name: asset['assigned_to_user_name'],
                           asset_num: asset['sequence_num'],
                           asset_ain: asset['identifier'],
                           user_email: user_email,
                           asset_location: location,
                           asset_status: asset['state'].split("_").map(&:capitalize).join(' '))
              else
                result = t('ez_checkout_asset.checkout_error', asset_name: asset_result['asset']['name'],
                            checkout_result: checkout_result.to_s)
              end
            end 
          end 
        else
          result = t('ez_checkout_asset.asset_not_found')
        end  
      response.reply(result)
      end                   

##############################################
################## HELPERS ###################
##############################################

      def get_data_from_ez(url)
        c = Curl.get("#{url}") do |curl|
          curl.headers['token'] = "#{config.jira.ez_office_token}"
        end
        c.perform
        return JSON.parse("#{c.body_str}")
      end

      def get_assets_by_filter(url)
        all_assets = Array.new
        body = get_data_from_ez("#{url}&include_custom_fields=false")
        pages = body['total_pages']
        if pages.to_i > 0
          all_assets += body['assets']
          for page in 2..pages.to_i do
            all_assets += get_data_from_ez("#{url}&page=#{page}&include_custom_fields=false")['assets']
          end
        end
        return all_assets
      end

      def get_all_assets_in_ez(url)
        all_assets = Array.new
        body = get_data_from_ez("#{url}?include_custom_fields=true")
        pages = body['total_pages']
        if pages.to_i > 0
          all_assets += body['assets']
          for page in 2..pages.to_i do
            all_assets += get_data_from_ez("#{url}?page=#{page}&include_custom_fields=true")['assets']
          end
        end
        return all_assets
      end

      def search_ez(url, search_str)
        all_assets = Array.new
        search_str = search_str.gsub(' ', '%20')

        asset_page_size = MAX_EZ_RESULTS_PAGE_SIZE
        page = 1
        while asset_page_size == MAX_EZ_RESULTS_PAGE_SIZE
          page_search_url = "#{url}?page=#{page}&search=#{search_str}&include_custom_fields=true"
          page_assets = get_data_from_ez(page_search_url)['assets']
          asset_page_size = page_assets.length
          all_assets += page_assets
          page += 1
        end

        return all_assets
      end

      def search_ez_users(url, email_str)
        search_url = "#{url}?facet=User&search=#{email_str}&include_custom_fields=true"
        user = get_data_from_ez(search_url)['assets'][0]

        return user
      end

      def get_asset_result(asset)
        result = "\n<#{config.jira.ez_office_site}/#{asset['sequence_num']}|#{asset['sequence_num']}"\
                 " - #{asset['name']}>  *AIN*: #{asset['identifier']}  *Status*: "\
                 "#{asset['state'].split("_").map(&:capitalize).join(' ')}"
        if asset['state'] == CHECKOUT_STATE_EZ
          result += "  *Assigned to*: #{asset['assigned_to_user_name']}"
        end
        return result
      end

      def get_num_overdue_days(asset)
        # checkin_due_on shows only date and time based on timezone of user. Time.parse method will
        # return to utc timezone, mean +00:00 but the time is still kept.
        # Ex: checkin_due_on = 2017-08-28 23:59:00 . After parsed => 2017-08-28 23:59:00 +0000
        due_time = Time.parse(asset['checkin_due_on'])
        # The current token is PST (US & Canada) so we need to convert due_time to timezone -08:00
        # without changing time to match each other. Ex: After converted: 2017-08-28 23:59:00 -0800
        due_time = Time.new(due_time.year, due_time.month, due_time.day,
                            due_time.hour, due_time.min, due_time.sec, "-08:00")
        current_time = Time.now.getlocal('-08:00')
        days_between = (current_time.to_i - due_time.to_i) / (24 * 60 * 60)
        return days_between
      end

      def get_all_members_in_ez(url)
        all_members = Array.new
        all_members += get_data_from_ez("#{url}?page=all&include_custom_fields=true")
        return all_members
      end

      def find_location_id(location_name)
        location_id = ""
        locations = get_data_from_ez("#{config.jira.ez_office_site}/get_line_item_locations.api"\
                                     .gsub('assets', 'locations'))
        locations.each do |location|
          if location['name'].downcase == location_name.downcase
            location_id = location['sequence_num']
            break
          end
        end
        return location_id
      end

      def find_member_by_email(email)
        member = search_ez_users("#{config.jira.ez_office_site}.api".gsub('assets', 'search'), email)

        unless member.nil?
          if member['email'].downcase == email.downcase
            return member
          end
        end

        return ""
      end

      def checkout_asset_to_user(user_id, location, asset_num, comment)
        url ="#{config.jira.ez_office_site}/#{asset_num}/checkout.api?user_id=#{user_id}"
        str_json ="{
                    \"checkout_values\":
                      {\"location_id\" : #{location},
                       \"comments\" : \"#{comment}\"
                      }
                   }"
        c = Curl::Easy.http_put("#{url}", str_json) do |curl|
              curl.headers['Accept'] = 'application/json'
              curl.headers['Content-Type'] = 'application/json'
              curl.headers['token'] = "#{config.jira.ez_office_token}"
            end
        return c
      end                       

      def is_number(str)
        str !~ /\D/
      end

      def is_email_address(search_str)
        (search_str =~ EMAIL_REGEX)
      end

      def get_asset_by_id(asset_num)
        asset = get_data_from_ez("#{config.jira.ez_office_site}/#{asset_num}.api")['asset']
        result = get_asset_result(asset)
        return result
      end

      def get_assets_by_member_id(member_id)
        member_assets_url = "#{config.jira.ez_office_site}/filter.api?"\
                            "status=possessions_of&filter_param_val=#{member_id}"
        assets = get_data_from_ez(member_assets_url)['assets']

        return assets
      end
      
      def get_assets_by_search(search_str)
        result = ''
        assets = search_ez("#{config.jira.ez_office_site}.api".gsub('assets', 'search'), search_str)

        assets.each do |asset|
          result += get_asset_result(asset)
        end

        return result
      end

      # rubocop:enable Metrics/AbcSize
    end
    # rubocop:enable Metrics/ClassLength
    Lita.register_handler(EzOfficeInventory)
  end
end
