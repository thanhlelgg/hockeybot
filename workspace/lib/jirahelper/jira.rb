module JiraHelper
  # Jira
  module Jira

    # Add comment for Jira issue
    def add_comment(client, issue, adding_comment)
      comment = issue.comments.build
      comment.save!(:body => adding_comment)
    end

    # Generate comments or description for bug
    def generate_jira_error_description(apprun, occurrences, app, period, site, add_logfile)
      time_day = Time.new - (24*60*60)
      time_week = time_day - (6*24*60*60)
      if (site =='prod')
        site = 'PROD'
      else
        site = 'DEV/BETA'
      end

      occurrences_day   = "#{occurrences} occurrences on #{time_day.strftime('%B-%d-%Y')} on #{site}.\n"
      occurrences_week  = "#{occurrences} occurrences from #{time_week.strftime('%B-%d-%Y')} to" \
                          "#{(time_day.strftime('%B-%d-%Y'))}.\n"
      no_apprun_log     = "Apprun: #{apprun}.\nBuild version: #{app}."
      attach_apprun_log = "@apprunbot apprun #{apprun}\nBuild version: #{app}."

      if add_logfile
        if(period == 'day')
          return "#{occurrences_day}#{attach_apprun_log}"
        else
          return "#{occurrences_week}#{attach_apprun_log}"
        end
      else
        if(period == 'day')
          return "#{occurrences_day}#{no_apprun_log}"
        else
          return "#{occurrences_week}#{no_apprun_log}"
        end
      end
    end

    # exclude special characters that conflict with JQL queries
    def jql_search_formatting(summary)
      summary = summary.gsub('&lt;', '<')
                       .gsub('&gt;', '>')
                       .gsub('&amp;', '&')
                       .gsub('-', '\\-')
                       .gsub('?', '\\?')
                       .gsub('[', '\\[')
                       .gsub(']', '\\]')
                       .gsub('(', '\\(')
                       .gsub(')', '\\)')
                       .gsub('{', '\\{')
                       .gsub('}', '\\}')
                       .gsub('*', '\\*')
                       .gsub('!', '\\!')
                       .gsub("'", '')
                       .gsub(/\\/) { '\\\\' }

      summary = summary[0..235]
    end

    # Check if issue already include attached logile or not
    def does_attachment_exist(issue_key)
      add_attachment = false
      attachments_issue_url = "#{config.jira.site}/rest/api/2/issue/#{issue_key}?fields=attachment"
      c = client.get(attachments_issue_url)
      no_attachments_regular = '"fields":{"attachment":[]}'
      if (c.body.include? no_attachments_regular)
        add_attachment = true
      end
      return add_attachment
    end

    # Integrate with Jira to create/reopen/add comments for Jira bugs from Mode reported errors
    def update_jira_with_mode_report_data(json_data, project, period, site, number_occurrences, labels, log_warning, is_prod_env)
      release_version_android = get_last_release_version_android(project)
      release_version_ios = get_last_release_version_ios(project)
      release_version =[release_version_android, release_version_ios].min
      if (json_data != nil)
        # client = connect_to_jira(jira_username, jira_password, jira_site)
        json_data.each do |key|
          # Handle the event contain ',' characters
          if(Float(key['occurrences']) != nil rescue false)
          else
            key['event'] = key['event'] + key['app']
            key['app'] = key['occurrences']
            key['occurrences'] = key['sample_apprun']
            key['sample_apprun'] = key['']
          end
          # Get the values of data
          level = key['level'].upcase
          event = key['event']
          app = key['app']
          occurrences = String(key['occurrences'])
          apprun = String(key['sample_apprun'])
          key['jiraid'] = ''
          key['notes'] = ''
          key['app'] = filter_prod_build(release_version, app.split("\n"), is_prod_env)
          # Get affects_version from build_version
          affects_versions = get_affects_versions(key['app'].split("\n"), project)
          if (log_warning != 'NO') || (level != 'WARN')
            summary = "#{level}-#{event}"
            summary = jql_search_formatting(summary)
            issues_jql = "PROJECT = '#{project}' AND Summary~'#{summary}' ORDER BY status ASC"
            log.info "--------#{issues_jql}"
            issues = fetch_issues(issues_jql)
            if (number_occurrences.to_i < occurrences.to_i)
              if String(issues) == '[]'
                if !summary[/\w/].nil?
                  issues_jql = handle_special_jql(project, summary)
                  issues = fetch_issues(issues_jql)
                end
              end
              # Create new bug and add logfile
              if String(issues) == '[]'
                description = generate_jira_error_description(apprun, occurrences, app, period, site, true)
                new_issue = create_issue(project, summary, description, 'error', nil, nil, nil)
                if(new_issue != nil)
                  # Add triage label to new bug
                  new_issue = fetch_issues(issues_jql)
                  label_issue(new_issue.first, "triage")

                  key['jiraid'] = new_issue.first.key
                  key['notes'] = 'Created new bug and attached logfile'
                  log.info "created new bug: #{key['jiraid']}"
                  log.info "jql = #{issues_jql}"
                end
                invalid_versions = update_affects_version(new_issue.first, affects_versions)
                key['notes'] = key['notes'] + invalid_versions

              else
                ks_issue = check_ks_issue(issues.first)
                app = key['app']
                if ((app != "") and (ks_issue == false))
                  # Check if bug already contains logfile or not 
                  add_logfile = does_attachment_exist(issues.first.key)
                  # Bug's comment to call saibot to help attach logifle into new issue
                  new_comment = generate_jira_error_description(apprun, occurrences, app, period, site, add_logfile)

                  # Reopen bug if closed
                  if ((issues.first.fields['status']['name'] == 'Done') |
                      (issues.first.fields['status']['name'] == 'Closed') |
                      (issues.first.fields['status']['name'] == 'Resolved'))
                    transition = issues.first.transitions.build()
                    project_transitions = eval(config.jira.project_open_transitions)
                    transition.save(:transition => {:id => "#{project_transitions[project]}"})

                    # Add comment notes
                    key['notes'] = 'Reopened'
                    log.info "re-opened bug and commented on: #{issues.first.key}"
                    log.info "jql = #{issues_jql}"

                  else
                    # Add comment notes for existing open bugs
                    key['notes'] = 'Added comment'
                    log.info "bug still open, commented on: #{issues.first.key}"
                    log.info "jql = #{issues_jql}"

                    # Add "triage" label for the open bugs that have not been assigned
                    if (issues.first.labels.include?("triage") == false && issues.first.assignee == nil)
                      label_issue(issues.first, "triage")
                    end
                  end
                  add_comment(client, issues.first, new_comment)
                  invalid_versions = update_affects_version(issues.first, affects_versions)
                  key['notes'] = key['notes'] + invalid_versions
                  key['jiraid'] = issues.first.key
                else
                  key['notes'] = 'Occurs on old build version, ignoring.'
                end
              end
            else
              key['notes'] = 'Occurrences not satisfied'
            end
          end
        end
        json_data
      else
        return json_data
      end
    end

    # Get the id of build
    def get_app_ids(project, hockeyapp_app_ids)
      build_ids = Hash.new
      project_ids = JSON.parse(hockeyapp_app_ids)
      app_id = project_ids[project]
      hockeyapp_url ="#{config.jira.hockeyapp_url}/#{app_id}/app_versions"
      # Connect to HockeyApp
      c = Curl::Easy.new(hockeyapp_url)
      c.headers["X-HockeyAppToken"] = config.jira.hockeyapp_token.to_s
      c.perform
      # Generate the app version list
      body_url = c.body_str
      app_versions = JSON.parse(body_url)['app_versions']
      # Get the latest app version
      latest_app_version = app_versions[0]['shortversion'].split(".")[0..2].join(".")
      all_current_build_id = Array.new
      app_versions.each do |version|
        short_version = version['shortversion'].split(".")[0..2].join(".")
        if short_version == latest_app_version
          all_current_build_id.push(version['id'])
        else
          break
        end
      end
      build_ids[app_id.to_s] = all_current_build_id.sort
      return build_ids
    end

    def get_master_id(project)
      return get_app_ids(project, config.jira.hockeyapp_master_app_ids)
    end

    def get_all_master_ids()
      master_ids = Hash.new
      master_ids.merge!(get_master_id("OD"))
      master_ids.merge!(get_master_id("OD_IOS"))
      master_ids.merge!(get_master_id("COZMO"))
      master_ids.merge!(get_master_id("COZMO_IOS"))
      return master_ids
    end

    # Get the latest COZMO/ OD app version based on the Master/ RC/ Rewrap build
    def get_latest_app_version(project, hockeyapp_app_ids)
      project_ids = JSON.parse(hockeyapp_app_ids)
      app_id = project_ids[project]
      hockeyapp_url ="#{config.jira.hockeyapp_url}/#{app_id}/app_versions"
      # Connect to HockeyApp
      c = Curl::Easy.new(hockeyapp_url)
      c.http_auth_types = :basic
      c.headers["X-HockeyAppToken"] = config.jira.hockeyapp_token.to_s
      c.multipart_form_post = true
      c.perform
      # Generate the app version list
      app_versions = c.body_str
      # Get the latest app version
      app_version = JSON.parse(app_versions)['app_versions'][0]['shortversion']
      return app_version
    end

    # Get affects versions from build versions and project ID
    # Input: all app versions (E.g: 2.8.0.4093.170530.2332.d.3f70fae (6)  
    #                               2.8.0.4083.170528.0357.d.226d444 (16) 
    #                               2.8.0.4083.170528.0328.d.226d444 (546) 
    #                               2.7.0.91.170504.1948.d.a449bc2 (3) ) and project ID (E.g: "OD")
    # Output: affects versions (E.g: OD 2.8.0, OD 2.7.0)
    def get_affects_versions(input_affects_versions, project)
      output_affects_versions = Array.new
      input_affects_versions.each do |version|
        #Fix case app from store, it's version likes : 2.2.0 (12)
        real_version = get_real_version(version)
        full_version = project + " " + real_version.split(".")[0..2].join(".")
        unless output_affects_versions.include? full_version
          output_affects_versions.push(full_version)
        end
      end
      return output_affects_versions
    end
 
    #Remove occurences from input affect version
    #Input  : 2.8.0.4093.170530.2332.d.3f70fae (6)
    #Output : 2.8.0.4093.170530.2332.d.3f70fae
    def get_real_version(affect_version)
      version = affect_version
      idx_space = affect_version.index(" ")
      unless idx_space.nil?
        version = affect_version[0..idx_space-1]
      end
      return version
    end

    def filter_prod_build(prod_version, app_versions_arr, is_prod_env)
      # sort the version by descending, latest version will be on the first
      new_build = []
      all_versions = app_versions_arr.sort.reverse
      versions_hash = Hash.new

      # handle some builds has already short version by temporarily remove occurence
      all_versions.each do |version|
        versions_hash[version.partition(" ").first] = version.partition(" ").last
      end

      #handle UNKNOWN version
      if versions_hash.keys.any? {|key| key == "UNKNOWN"}
        versions_hash.delete("UNKNOWN")
      end

      # all versions has alphabet at first are the old version so we dont care about these versions, delete it
      versions_hash.delete_if do |version, occurence|
        if (version[0] =~ /[A-Z]/)
          true
        end
      end

      versions_hash.each do |version, occurence|
        # Get 3 first numbers
        version_arr = version.split(".")
        short_version = version_arr[0..2].join(".")
        is_select = false
        if(is_prod_env)
          is_select = Gem::Version.new(short_version) >= Gem::Version.new(prod_version)
        else
          is_select = Gem::Version.new(short_version) > Gem::Version.new(prod_version)
        end
        if (is_select)
          new_build << "#{version} #{occurence}"
          next
        else
          break
        end
      end

      if (new_build.length != 0)
        filtered_build = new_build.join("\n")
      else
        filtered_build = ""
      end

      return filtered_build
    end

    #Get list clean up issues not updated over a week on jira
    def issues_to_close(project)
      close_ticket_timeout = config.jira.close_ticket_timeout.to_i
      jql = "PROJECT = '#{project}' AND status in ('Open', 'In Progress', 'Code Review')
            AND component = 'errors' AND updated <= -#{close_ticket_timeout}d
            ORDER BY updated DESC, key ASC, summary ASC"
      ret = fetch_issues(jql)
      return ret
    end

    def convert_to_readable_time(num_of_day)
      time = ""
      if (num_of_day == 7)
        time = "week"
      elsif (num_of_day >= 28 and num_of_day <= 31)
        time = "month"
      elsif (num_of_day == 365 or num_of_day == 366)
        time = "year"
      else
        time = "#{num_of_day} days"
      end
      return time
    end

    def close_issue( project, issue, description)
      #1. Add comment
      add_comment(client, issue, description)

      #2. Close issue
      transition = issue.transitions.build()
      projects = eval(config.jira.projects)
      jira_project = projects[project]
      project_transitions = eval(config.jira.project_close_transitions)
      status_issue = issue.fields['status']['name'].to_s
      action_id = project_transitions[jira_project][status_issue]
      action_id.each do |action|
        transition.save(:transition => {:id => "#{action}"})
      end
    end

    def get_master_version(project)
      master_version = ""
      master_version = get_latest_app_version(project, config.jira.hockeyapp_master_app_ids)
      master_version = master_version[0,5]
      return master_version
    end

    def get_last_release_version_ios(project)
      last_release_version = ""
      package_apps = JSON.parse(config.jira.package_apps)
      package_app = package_apps[project]
      url_ios = "#{config.jira.url_applestore_api}#{package_app}"
      c = Curl::Easy.new(url_ios)
      c.perform
      json_info = JSON.parse(c.body_str)
      last_release_version = json_info['results'][0]['version'].to_s
      return last_release_version
    end

    def get_last_release_version_android(project)
      last_release_version = nil
      package_apps = JSON.parse(config.jira.package_apps)
      package_app = package_apps[project]
      url_android = "#{config.jira.url_googleplay_api}#{package_app}"
      # There's a slight chance that the current version can't be retrieved in one try,
      # but it's guarenteed to be retrieved after a few tries. Not takes long and more stable
      # Also we have timeout setting, so it won't be running forever
      begin
        Timeout::timeout(config.mode.query_timeout.to_i) {
          while last_release_version == nil do
            c = Curl::Easy.new(url_android)
            c.perform
            last_release_version = get_current_version_from_play_store_html(c.body_str)
            sleep(1)
          end
        }
      rescue Timeout::Error
        log.info "Timeout Error: Unable to grab the production app version from the google play store. 
                  Please try again!"
      end
      return last_release_version
    end

    def get_current_version_from_play_store_html(html_content)
      current_path = File.dirname(__FILE__)
      json = File.read("#{current_path}/../../lita_config.json") 
      data = JSON.parse(json)
      regex = data['version_regex'].join("")
      return html_content[/#{regex}/,1]
    end

    def exclude_crash_versions(project)
      exclude_versions = []
      master_version = get_master_version(project).to_s
      last_release_version_ios = get_last_release_version_ios(project)
      last_release_version_android = get_last_release_version_android(project)
      release_version =[last_release_version_ios, last_release_version_android].min.to_s
      (release_version..master_version).each do |version|
        exclude_versions.push("#{version}")
      end
      return exclude_versions
    end

    def contain_exclude_versions(version, list_exclude_versions)
      contain_exclude_version = false
      list_exclude_versions.each do |exclude_version|
        if version.include? exclude_version
          contain_exclude_version = true
          break
        end
      end
      return contain_exclude_version
    end

    def crash_issues_to_clean_up(project)
      jql = "project = '#{project}' AND issuetype = Bug AND status in ('To Do','Open') 
            AND assignee is EMPTY AND component = crashes AND affectedVersion != EMPTY 
            AND updated <= -#{config.jira.close_ticket_timeout}d ORDER BY affectedVersion ASC"
      crash_issues = fetch_issues(jql)
      return crash_issues

    end

    def last_comment(issue_key)
      last_comment = nil
      comments_issue_url = "#{config.jira.site}/rest/api/2/issue/#{issue_key}/comment"
      c = client.get(comments_issue_url)
      json_info = JSON.parse(c.body)
      total_comment = json_info["total"].to_i
      last_comment = json_info["comments"][total_comment-1]
      return last_comment
    end

    def content_last_comment(issue_key)
      content = ""
      comment = last_comment(issue_key)
      if(comment != nil)
        content = comment["body"].to_s
      end
      return content
    end

    def last_updated_day(issue_key)
      day = ""
      comment = last_comment(issue_key)
      if(comment != nil)
         day = comment["updated"].to_s
         time = Time.parse("#{day}")
         #Convert day as format mm/dd/yyyy
         day = time.strftime('%D').to_s
      end     
      return day
    end

    def ks_error_issues_to_cleanup(project)
      # the VIP-Category column in anki jira has id cf[11404]
      vipCateColumn = "cf[11404]"
      jql = "project = #{project} AND status in (Open, 'In Progress', 'Code Review', 'Test Ready')
      AND component = errors AND VIP-Category in ('101 (KS)', '001 (KS)') ORDER BY #{vipCateColumn} ASC, summary ASC"
      ks_issues = fetch_issues(jql)
      return ks_issues
    end

    def all_affected_version(issue)
      affected_versions = ""
      if issue.fields["versions"].size > 0
        lst_affected_version = issue.fields["versions"]
        lst_affected_version.each do |item|
          affected_versions = "#{affected_versions}, #{item["name"].to_s}"
        end
      end
      return affected_versions
    end

    def check_ks_issue(issue)
      ks_issue = false
      vipCateColumn = eval(config.jira.vip_category_column)
      vipCateColumnField = issue.fields[vipCateColumn['name']]
      if (vipCateColumnField != nil)
        vipCateColumn['value']['KS'].each do |ks_value|
          if (vipCateColumnField['value'] == ks_value)
            ks_issue = true
            break
          end
        end
      end
      return ks_issue
    end

    def label_issue(issue, label)
      issue.save(update: { labels: [ {add: label} ] })
    end

    def current_crash_count(issue_key)
      issue = fetch_issue(issue_key)
      crash_count = issue.fields['customfield_11602']
      return crash_count
    end
    
    def add_affects_version(issue, affects_version)
      issue.save(update: { versions: [ {add: {name: affects_version}} ] })
    end
    
    def update_production_app_version()
      results = []
      app_names = JSON.parse(config.jira.package_apps).keys 
      app_names.each do |project_name|
        release_version_android = get_last_release_version_android(project_name)
        release_version_ios = get_last_release_version_ios(project_name)
        release_version =[release_version_android, release_version_ios].min
        results.push("#{project_name} #{release_version}")
      end
      return results.join(", ")   
    end

    def handle_special_jql(project, summary)
      jql = "PROJECT = '#{project}'"
      separated_summary = summary.split(/\W+/)
      separated_summary.each do |token|
        if token != ""
          jql << " AND Summary~'#{token}'"
        end
      end
      jql << " ORDER BY Summary"
      return jql
    end
  end
end
