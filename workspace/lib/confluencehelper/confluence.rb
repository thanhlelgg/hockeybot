require 'active_support/core_ext/hash'
require "rest-client"

module ConfluenceHelper
  module Confluence

    def update_release_schedule(build, detail)
      result = ""
      updated_schedule = nil
      schedule = get_release_schedule(build)
      object_schedule = convert_to_schedule(build, detail)
      if object_schedule.length > 0
        if schedule.length == 1
          updated_schedule = change_release_schedule(schedule[0], object_schedule)
          result = "Updated"
        else
          updated_schedule = add_release_schedule(object_schedule)
          result = "Added"
        end
        status = push_update_schedule(updated_schedule)
        result = "#{result} release schedule for #{build} is #{status}."
      else
        result = t("help.release_schedule.error")
      end
      return result
    end

    def change_release_schedule(old_schedule_item, infor_schedule)
      release_schedule = get_current_release_schedule()
      old_build_name = information_schedule_item(old_schedule_item, ConfluenceConstant::BUILD)
      release_schedule.each do |schedule_item|
        build_name = information_schedule_item(schedule_item, ConfluenceConstant::BUILD)
        if build_name != nil
          if build_name.downcase.include? old_build_name.downcase
            update_information_schedule_item(schedule_item, infor_schedule)
            break
          end
        end
      end
      return release_schedule
    end

    def update_information_schedule_item(schedule_item, new_schedule_item)
      change_information_schedule_item(schedule_item, ConfluenceConstant::BRANCH_DATE, 
        new_schedule_item[ConfluenceConstant::BRANCH_DATE])
      change_information_schedule_item(schedule_item, ConfluenceConstant::SUBMIT_DATE, 
        new_schedule_item[ConfluenceConstant::SUBMIT_DATE])
      change_information_schedule_item(schedule_item, ConfluenceConstant::RELEASE_DATE, 
        new_schedule_item[ConfluenceConstant::RELEASE_DATE])
    end

    def add_release_schedule(infor_schedule_item)
      release_schedule = get_current_release_schedule()
      new_schedule = convert_string_to_schedule(infor_schedule_item)
      release_schedule.push(new_schedule)
      return release_schedule
    end

    def convert_string_to_schedule(infor_schedule_item)
      schedule = nil
      json = File.read("#{Dir.pwd}/../lita_config.json")
      data = JSON.parse(json)
      json_release_schedule = data["release_schedule"]
      schedule_item =  json_release_schedule["schedule_item"].join("")
      schedule_item["%{build}"] = infor_schedule_item[ConfluenceConstant::BUILD]
      schedule_item["%{branch}"] = infor_schedule_item[ConfluenceConstant::BRANCH_DATE]
      schedule_item["%{submit}"] = infor_schedule_item[ConfluenceConstant::SUBMIT_DATE]
      schedule_item["%{release}"] = infor_schedule_item[ConfluenceConstant::RELEASE_DATE]
      schedule = JSON.parse(schedule_item)
      return schedule
    end

    def push_update_schedule(updated_schedule)
      updated_value = format_schedule_to_put(updated_schedule)
      return put_update_schedule(updated_value)
    end

    def convert_to_html(release_schedule_format, updated_schedule)      
      html_content = release_schedule_format["header"].join("")
      updated_schedule.each do |schedule_item|
        row_result =  release_schedule_format["row"].join("")
        build = information_schedule_item(schedule_item, ConfluenceConstant::BUILD)
        branch = information_schedule_item(schedule_item, ConfluenceConstant::BRANCH_DATE)
        submit = information_schedule_item(schedule_item, ConfluenceConstant::SUBMIT_DATE)
        release = information_schedule_item(schedule_item, ConfluenceConstant::RELEASE_DATE)
        row_result["%{build}"] = build
        row_result["%{branch}"] = branch
        row_result["%{submit}"] = submit
        row_result["%{release}"] = release
        html_content = html_content + row_result
      end
      html_content = html_content + release_schedule_format["end_html"]
      return html_content
    end

    def format_schedule_to_put(updated_schedule)
      information_schedule = ""      
      json = File.read("#{Dir.pwd}/../lita_config.json")
      data = JSON.parse(json)
      json_release_schedule = data["release_schedule"]
      updated_value = convert_to_html(json_release_schedule, updated_schedule)
      current_title = current_title_page("#{config.jira.release_page_id}")
      current_version = current_version_page("#{config.jira.release_page_id}")
      current_version = current_version + 1
      information_schedule = json_release_schedule["content"].join("")
      information_schedule["%{id}"] = config.jira.release_page_id
      information_schedule["%{title}"] = current_title
      information_schedule["%{updated_value}"] = updated_value
      information_schedule["%{version}"] = "#{current_version}"
      return information_schedule
    end

    def information_schedule_item(schedule_item, index_item)
      value_item = schedule_item[ConfluenceConstant::TD_HTML][index_item][ConfluenceConstant::STYLE_CSS_DATA]
      if value_item == nil
        value_item = ""
      end
      return value_item
    end

    def change_information_schedule_item(schedule_item, index_item, new_value)
      if new_value != ""
        schedule_item[ConfluenceConstant::TD_HTML][index_item][ConfluenceConstant::STYLE_CSS_DATA] = new_value 
      end
    end

    def put_update_schedule(updated_value)
      result = "fail"
      release_page_url = "#{config.jira.site}/wiki/rest/api/content/#{config.jira.release_page_id}"
      private_resource = RestClient::Resource.new release_page_url, config.jira.username, config.jira.password
      response = private_resource.put updated_value, :content_type => 'application/json'      
      if response.code == 200
        result = "successful"
      end
      return result
    end

    def current_version_page(page_id)
      url = "#{config.jira.site}/wiki/rest/api/content/#{page_id}?expand=version"
      result = client.get(url)
      jsonObj = JSON.parse(result.body)
      return jsonObj['version']['number']
    end

    def current_title_page(page_id)
      url = "#{config.jira.site}/wiki/rest/api/content/#{page_id}"
      result = client.get(url)
      jsonObj = JSON.parse(result.body)
      return jsonObj['title']
    end

    def convert_to_schedule(build, information_schedule)
      schedule_item = Array.new
      branch_date = information_detail(information_schedule, ConfluenceConstant::BRANCH_DATE_NAME)
      submit_date = information_detail(information_schedule, ConfluenceConstant::SUBMIT_DATE_NAME)
      release_date = information_detail(information_schedule, ConfluenceConstant::RELEASE_DATE_NAME)
      if (branch_date != nil && submit_date != nil && release_date != nil)
        schedule_item.push(build)
        schedule_item.push(branch_date)
        schedule_item.push(submit_date)
        schedule_item.push(release_date)
      end      
      return schedule_item
    end

    #information_schedule : branch 5/6/17, submit 6/2/17, release 6/6/17
    def information_detail(information_schedule, item_name)
      information = ""
      if information_schedule.include? item_name
        index_item = information_schedule.index(item_name)
        temp_schedule = information_schedule[index_item..-1]
        index_delimiter = temp_schedule.index(",")
        index_start = item_name.length
        index_end = (index_delimiter != nil) ? index_delimiter - 1 : -1
        information = temp_schedule[index_start..index_end]
        if !(is_valid_day(information))
          information = nil
        end
      end
      return information
    end

    def is_valid_day(information_day)
      is_valid = false
      #Format day : mm/dd/yy
      format_day = information_day.match(/^\d{1,2}\/\d{1,2}\/\d{1,2}\z/)
      if format_day != ""
        month, day, year = information_day.split("/")
        year = "20#{year}"
        is_valid = Date.valid_date?(year.to_i, month.to_i, day.to_i)
      end
      return is_valid
    end

  end
end
