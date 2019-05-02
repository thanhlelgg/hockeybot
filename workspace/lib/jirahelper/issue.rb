# Helper functions for lita-jira
module JiraHelper
  # Issues
  module Issue
    # NOTE: Prefer this syntax here as it's cleaner
    # rubocop:disable Style/RescueEnsureAlignment

    # Update affects versions to Jira
    def update_affects_version(issue, input_affects_versions)
      invalid_affects_versions = ""
      all_affects_versions = all_affected_version(issue)
      input_affects_versions.each do |version|
        unless all_affects_versions.include? version
          add_affects_version(issue, "#{version}")
        end
      end
      # we do this loop twice because jira does not update the issue immediately,
      # so we cannot check the invalid version right after adding the version into issue on jira.
      # Check affects versions that does not match with affects versions on Jira
      # We should re-get issue to get the latest information before checking
      issue = fetch_issue(issue.key)
      all_affects_versions = all_affected_version(issue)
      input_affects_versions.each do |version|
        unless all_affects_versions.include? version
          invalid_affects_versions += version + "\n"
        end
      end
      if invalid_affects_versions.length != 0
        invalid_affects_versions = "\nAffects versions are not available in Jira:\n" + invalid_affects_versions
      end
      return invalid_affects_versions
    end

    def fetch_issue(key, expected = true)
      if !(key =~ /[A-Za-z]-[0-9]{1,5}/)
        key = key.gsub(/(?<=[A-Za-z])(?=[0-9])/, '-')
      end
      client.Issue.find(key)
      rescue
        log.error('JIRA HTTPError') if expected
        nil
    end
    # rubocop:enable Style/RescueEnsureAlignment

    # Leverage the jira-ruby Issue.jql search feature
    #
    # @param [Type String] jql Valid JQL query
    # @return [Type Array] 0-m JIRA Issues returned from query
    def fetch_issues(jql)
      issues = []
      max_result = config.jira.max_results.to_i
      query_options = {
        :fields => [],
        :start_at => 0,
        :max_results => max_result
      }
      begin 
        temp_issues = []
        temp_issues = client.Issue.jql(jql, query_options)
        while (temp_issues.length > 0)
          issues += temp_issues
          query_options[:start_at] += max_result
          temp_issues = client.Issue.jql(jql, query_options)
        end
      rescue JIRA::HTTPError => e
        issues = nil
        log.error('JIRA HTTPError')
      end
      return issues
    end

    def fetch_issues_by_filter_id(id)
      issues = []
      begin
        jql = client.Filter.find(id).jql
        issues = fetch_issues(jql)
      rescue => ex
        log.info("#{ex.message}")
      end
      return issues
    end

    # NOTE: Prefer this syntax here as it's cleaner
    # rubocop:disable Style/RescueEnsureAlignment
    def fetch_project(key)
      client.Project.find(key)
      rescue
        log.error('JIRA HTTPError')
        nil
    end
    # rubocop:enable Style/RescueEnsureAlignment

    # NOTE: Not breaking this function out just yet.
    # rubocop:disable Metrics/AbcSize
    def format_issue(issue)
      t(config.jira.format == 'one-line' ? 'issue.oneline' : 'issue.oneline',
        key: issue.key,
        summary: issue.summary,
        status: issue.status.name,
        assigned: optional_issue_property('unassigned') { issue.assignee.displayName },
        url: format_issue_link(issue.key))
    end

    def format_issue_description(issue)
      t('issue.description',
        key: issue.key,
        summary: issue.summary,
        description: issue.description,
        url: format_issue_link(issue.key))
    end

    def format_issue_full(issue)
      t(config.jira.format == 'one-line' ? 'issue.oneline' : 'issue.details',
        key: issue.key,
        summary: issue.summary,
        status: issue.status.name,
        assigned: optional_issue_property('unassigned') { issue.assignee.displayName },
        fixVersion: optional_issue_property('none') { issue.fixVersions.first['name'] },
        priority: optional_issue_property('none') { issue.priority.name },
        vipCategory: optional_issue_property('none') { issue.customfield_11404.values[1] },
        url: format_issue_link(issue.key))
    end

    def format_issue_list(issue)
      t('issue.small',
        key: issue.key,
        status: issue.status.name,
        url: format_issue_link(issue.key))
    end

    def get_teamcity_url(build_type, branch, pull_request)
      return config.jira.teamcity_uri +
            "/viewType.html?buildTypeId=#{build_type}"\
            "&branch_#{branch}_Dev=#{pull_request}"\
            "%2Fhead&tab=buildTypeStatusDiv"
    end

    def get_build_info_from_key(key)
      build_info = Hash.new
      project_id = key.split('-')[0]
      build_info['ios'] = config.jira.teamcity_info[project_id][0]
      build_info['android'] = config.jira.teamcity_info[project_id][1]
      build_info['branch'] = config.jira.teamcity_info[project_id][2]
      return build_info
    end

    def build_slack_link(url, name)
      return "<" + url + "|" + name + "> "
    end

    def format_issue_pr(pull_requests, issue)
      build_info = get_build_info_from_key(issue.key)
      prs = t('git.no_pr')

      if not build_info.empty?
        prs = "\n"
        pull_requests.each do |pr|
          prs += build_slack_link(pr['url'], pr['id']) + " "

          unless build_info['ios'].empty?
            ios_link = get_teamcity_url(build_info['ios'],
                                        build_info['branch'],
                                        pr['id'][1..-1])
            prs += build_slack_link(ios_link, t('issue.ios')) + " "
          end

          unless build_info['android'].empty?
            android_link = get_teamcity_url(build_info['android'],
                                            build_info['branch'],
                                            pr['id'][1..-1])
            prs += build_slack_link(android_link, t('issue.android')) + "\n"
          end
        end
      end

      t('issue.pullrequest',
        key: issue.key,
        id: issue.id,
        summary: issue.summary,
        status: issue.status.name,
        pull_requests: prs,
        url: format_issue_link(issue.key))
    end

    # rubocop:enable Metrics/AbcSize

    # Enumerate issues returned from JQL query and format for response
    #
    # @param [Type Array] issues 1-m issues returned from JQL query
    # @return [Type Array<String>] formatted issues for display to user
    def duplicate_issue(issues)
      results = [t('hockeyappissues.duplicate')]
      results.concat(issues.map { |issue| format_issue_full(issue) })
    end

    def format_issue_link(key)
      "#{config.jira.site}#{config.jira.context}/browse/#{key}"
    end

    def fetch_dev_info(issue)
      #Undocumented way to get dev menu info from Jira
      #https://answers.atlassian.com/questions/32535478/get-commits-info-of-a-jira-issue-using-rest-api
      dev_info_url = "#{config.jira.site}#{config.jira.context}"\
                     "/rest/dev-status/latest/issue/detail?"\
                     "issueId=#{issue.id}&applicationType=github&dataType=pullrequest"
      return client.get(dev_info_url).body
    end

    def fetch_repo_info(issue)
      #Undocumented way to get dev menu info from Jira
      #https://answers.atlassian.com/questions/32535478/get-commits-info-of-a-jira-issue-using-rest-api
      repo_url = "#{config.jira.site}#{config.jira.context}"\
                 "/rest/dev-status/latest/issue/detail?"\
                 "issueId=#{issue.id}&applicationType=github&dataType=repository"
      return client.get(repo_url).body
    end

    # mode == 'NO': Create new issue for hockeyapp issue
    # mode != 'NO': Create new issue for Mode error/warning issue
    def create_issue(project, summary, description, type, affects_version, assignee, watchers)
      project_obj = fetch_project(project)
      return nil unless project_obj
      issue = client.Issue.build
      begin
        if type == 'crash'
          crash_component = config.jira.components.split(",")[0]
          issue.save(fields: { project: { id: project_obj.id },
                               issuetype: { id: '1' },
                               summary: summary,
                               components: [{ name: crash_component }],
                               versions: [{ name: affects_version }],
                               description: description })
          issue.fetch
          issue

        elsif type == 'error'
          error_component = config.jira.components.split(",")[1]
          issue.save(fields: { project: { id: project_obj.id },
                               issuetype: { id: '1' },
                               summary: summary,
                               components: [{ name: error_component }],
                               description: description })
          issue.fetch
          watcher_issue = issue.watches['self']

          # E.g. watcher_issue is "https://ankiinc.atlassian.net/rest/api/2/issue/AUT-31/watchers"
          issue_id = watcher_issue.split('issue/')[1].split('/watchers')[0]
          issue_id

        elsif type == 'task'
          task_component = config.jira.components.split(",")[2]
          issue.save(fields: { project: { id: project_obj.id },
                               issuetype: { id: '7' },
                               assignee: {name: assignee},
                               summary: "#{affects_version} #{summary}",
                               components: [{ name: task_component }],
                               customfield_11500: [{ name: "#{project} #{affects_version}" }],
                               description: description })
          issue.fetch
          issue
          jira_url = "#{config.jira.site}#{config.jira.context}/rest/api/2/issue/#{issue.key}/watchers"
          watchers.each do |watcher|
            c = Curl::Easy.http_post("#{jira_url}", watcher) do |curl|
              curl.headers['Content-Type'] = "application/json"
              curl.headers['Accept'] = "application/json"
            end
            c.username = config.jira.username
            c.password = config.jira.password
            c.perform
          end
          issue
        end
      rescue => ex
        return nil
      end
     
    end

    # Attempt to retrieve optional JIRA issue property value via a provided block.
    # JIRA properties such as assignee and priority may not exist.
    # In that case, the fallback will be used.
    #
    # @param [Type String] fallback A String value to use if the JIRA property value doesn't exist
    # @return [Type String] fallback or returned value from yield block
    def optional_issue_property(fallback = '')
      yield
    rescue
      fallback
    end
  end
end
