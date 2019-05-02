require 'lita/adapters/slack/message_handler'
require 'timeout'
# lita-jira plugin
module Lita
  # Because we can.
  module Handlers
    # Main handler
    # rubocop:disable Metrics/ClassLength
    class Mode < Handler
      namespace 'common'

      include ::ModeHelper::Mode
      include ::ModeHelper::Email
      include ::JiraHelper::Jira
      include ::JiraHelper::Issue
      include ::JiraHelper::Misc

      route(
      /.*mode_report(.*)/,
      :execute_daily_weekly_email_report,
      command: true,
      help: {t('help.report.syntax') => t('help.report.desc')}
      )

      route(
      /.*DAS(.*)/,
      :get_das_version ,
      command: true,
      help: {t('help.get_das_version.syntax') => t('help.get_das_version.desc')}
      )

      route(
      /.*vector_events(.*)/,
      :get_vector_events,
      command: false,
      help: {t('help.vector_events.syntax') => t('help.vector_events.desc')}
      )

      def get_vector_events(response)
        result = ""
        argument = response.matches[0][0].strip
        event_type = argument.downcase
        response.reply(t('vector_events.executing'))
        if is_event_supported(event_type)
          mode_link = get_mode_link_by_event(event_type)
          jsonData = get_data_from_mode_by_time_period("#{mode_link}")
          unless jsonData.empty?
            result = convert_hashes_to_readable_string(jsonData)
          else
            result = t('vector_events.empty_data')
          end
        else
          result = t('vector_events.invalid_event_name', argument_event: argument)
        end
        response.reply(result)
      end

      def get_das_version(response)
        databases_url = [config.mode.dev_das_version_url, 
                         config.mode.prod_das_version_url, config.mode.beta_das_version_url]

        arguments = response.matches[0][0].strip
        argument_project, argument_app_version, argument_build_id = arguments.split(' ')
        das_found = 0
        
        valid_project_name = get_valid_project_name(argument_project)
        if valid_project_name.nil?
          response.reply(t('das_version.invalid_project_name', argument_project: argument_project))
          return
        end

        results = []
        results.push(t('das_version.list_info',
                        argument_build_id: argument_build_id,
                        argument_project: valid_project_name,
                        argument_app_version: argument_app_version))
        table_name_json = JSON.parse(config.mode.das_table_name)
        parameter = "?param_table_name=#{table_name_json[valid_project_name]}"\
                    "&param_app_version=#{argument_app_version}&param_build_id=#{argument_build_id}&run=now"
        response.reply("Getting data from mode, this may take awhile...")
        databases_url.each do |mode_url|
          jsonData = get_data_from_mode_by_time_period("#{mode_url}#{parameter}")
          unless jsonData.empty?
            das_found += 1
            db_name = get_database_name(mode_url)
            jsonData.each do |key|
              results.push("#{db_name} on #{key['platform']} #{key['app']}")
            end
          end
        end

        if das_found > 1
          results.push(t('das_version.multil_db_found'))
        end

        if das_found == 0
          response.reply(t('das_version.no_das_found',
                            argument_app_version: argument_app_version,
                            argument_build_id: argument_build_id,
                            argument_project: argument_project))
        else 
          response.reply(results)
        end
      end

      # Handle the message is coming from a bot
      def execute_daily_weekly_email_report(response)
        # Get the message string that is sent from Slack
        # An example message string: mode_report day
        arguments = response.matches[0][0].strip
        argument_platform, argument_env, argument_period = arguments.split(' ')
        log_warning = config.mode.log_warning

        options = { :address              => 'smtp.gmail.com',
                    :port                 => 587,
                    :domain               => 'gmail.com',
                    :user_name            => config.mode.email_username,
                    :password             => config.mode.email_password,
                    :authentication       => 'plain',
                    :enable_starttls_auto => true  }

        if ((argument_period != 'day' and argument_period != 'week') or
            (argument_env !='dev' and argument_env != 'prod'))
          response.reply(t('help.report.error'))
        else
          response.reply(t('request.executing'))
          begin
            Timeout::timeout(config.mode.mode_report_timeout.to_i) {
              projects = eval(config.jira.projects)
              real_project = projects["#{argument_platform}".downcase]
              prod_env = false
              if (argument_env == 'prod')
                prod_env = true
              end
              mode_url = get_mode_url(argument_platform, prod_env)
              occurence = get_occurence(argument_platform, prod_env)

              # Get JSON data
              # Get the latest URL from Latest Error And Warning from Prod/ Dev
              jsonData = get_data_from_mode_by_time_period(mode_url.gsub('PERIOD', argument_period))
              if (jsonData.include? "#{RUNTIME_EXCEPTION_PREFIX_MESSAGE}")
                response.reply(jsonData)
                return
              end

              # Aggregation the events in the report
              jsonData = aggregate_event(jsonData)

              # Integrate Jira with JSON data
              jsonData = update_jira_with_mode_report_data(jsonData, real_project, argument_period, argument_env.upcase,
                occurence, config.mode.labels, config.mode.log_warning, prod_env)

              # Clean up
              close_issues = clean_up(argument_platform)

              # Generate the email template with returned datas from Jira
              emaildata = generate_email_template(close_issues, jsonData, argument_env.upcase, 
                argument_platform.upcase, argument_period)

              # Send mail to owner
              send_email(options, argument_platform, config.mode.to_email, config.mode.cc_email,
                         config.mode.email_username, emaildata, argument_period, argument_env.upcase)
              response.reply(t('email.sent_success', to_email: config.mode.to_email))
            }
          rescue Timeout::Error
            response.reply(t('request.timeout'))
          rescue => e
            response.reply("#{e.message}")
            response.reply("#{e.backtrace}")
          end
        end
      end
      
      def clean_up(project)
        #Step 1. Get list clean up issues not updated over a week on jira
        issues = issues_to_close(project)
        close_issues = Hash.new
        jsonData = get_all_errors_event(project)
        issues.each do |issue|
          summary = issue.fields['summary'].to_s
          if summary.include? '-'
            event_name = summary[summary.index('-')+1, summary.length ]
          else 
            event_name = summary
          end
          #Step 2. Query it on mode to see if the error still occurs
          #Step 2.1 : Query on dev link
          is_event_happen = event_still_occurs(event_name, jsonData)
          if(!is_event_happen)
            #Cache status before we close this issue for mail report
            previous_status = issue.fields["status"]["name"].to_s
            #Step 3.1. Close issue if it hasn't occurred in the last week, close as "Cannot reproduce"            
            time = convert_to_readable_time(config.jira.close_ticket_timeout.to_i)
            description = "Automatically closing ticket. Has not occurred in the last #{time}."
            close_issue(project, issue, description)
            close_issues[issue] = "#{previous_status}"
          end
        end
        return close_issues
      end

      def generate_report_html_for_close_issues(close_issues)
        header = '<tr><th>#</th><th width=\"30%\">Date</th><th width=\"20%\">Jira ID</th><th>Summary</th>
                  <th width =\"18%\">Status</th><th>Logigear\'s comment</th><th> Change status on Jira</th></tr>'
        str = "<table border=\"1\">\n#{header}\n"
        link_jira = "<a href =\"#{config.jira.site}/browse/BUGID\">BUGID</a>"
        number = 1
        changed_status = "Closed"
        if (close_issues != nil)
          close_issues.each do |issue, previous_status|
            issue_key = issue.key
            date = last_updated_day(issue_key)
            summary = issue.fields["summary"].to_s
            status = previous_status
            comment = content_last_comment(issue_key)
            str += "<tr><td align = \"center\">#{number.to_s}</td>
            <td>#{date}</td><td align = \"center\">#{link_jira.gsub('BUGID',issue_key)}</td>
            <td>#{summary}</td><td align = \"center\">#{status}</td>
            <td align = \"center\">#{comment}</td><td align = \"center\">#{changed_status}</td>
            </tr>\n"
            number+= 1
          end
        end
        str += '</table>'
        return str
      end

      # Input: data is a JSON format
      # Output: The HTML table
      def generate_report_html_from_json(data)
        report = []
        header = '<tr><th>#</th><th>Level</th><th width=\"30%\">Event</th><th>Build Version</th><th>Occurrences</th>
                  <th width =\"18%\">Sample Apprun</th><th>Notes</th><th>Jira ID</th></tr>'
        str = "<table border=\"1\">\n#{header}\n"
        link_jira = "<a href =\"#{config.jira.site}/browse/BUGID\">BUGID</a>"
        number = 1
        issue_keys = ""
        if (data != nil)
          data.each do |key|
            if (key['jiraid'] != "")
              issue_keys = "#{issue_keys} #{key['jiraid']}"
            end
            str += "<tr><td align = \"center\">#{number.to_s}</td><td align = \"center\">#{String(key['level'])}</td><td>
            #{key['level'].upcase}-#{key['event']}</td><td>#{String(key['app']).gsub('\n','<br>')}</td><td align = \"center\">
            #{String(key['occurrences'])}</td><td>#{String(key['sample_apprun'])}</td><td>#{String(key['notes'])}</td>
            <td align = \"center\">#{link_jira.gsub('BUGID',key['jiraid'])}</td></tr>\n"
            number+= 1
          end
        end
        str += '</table>'
        report.push(issue_keys)
        report.push(str)
        return report
      end
      
      # Input: data are two JSON formats, project
      # Output: The HTML email
      def generate_email_template(close_issues, jsonData, environment, project, period)
        num_issue = close_issues.size
        issue_keys = ""
        close_issues.each do |issue, previous_status|
          issue_keys = "#{issue_keys} #{issue.key}"
        end
        if (environment == 'DEV')
          environment = 'DEV/BETA'
        end
        table_close_issues = generate_report_html_for_close_issues(close_issues)
        table_json = generate_report_html_from_json(jsonData)
        emailBody = "<p>Dear Anki Team,</p><p>Below is the #{project} Top Error Report for this #{period}.
        We closed #{num_issue} bugs.</p><p>jiralist [#{issue_keys} ]</p><p>#{table_close_issues}</p>
        <p>There is the collected results for reported errors on #{project}:</p>
        <p><b>#{environment}</b></br><p>jiralist [#{table_json[0]} ]</p>#{table_json[1]}</p><p>Thanks,</p>AutoBot"
        return emailBody
      end

    end
    Lita.register_handler(Mode)
  end
end
