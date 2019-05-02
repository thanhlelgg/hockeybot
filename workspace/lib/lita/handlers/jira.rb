# lita-jira plugin
module Lita
  # Because we can.
  module Handlers
    # Main handler
    # rubocop:disable Metrics/ClassLength
    class Jira < Handler
      namespace 'common'

      include ::JiraHelper::Issue
      include ::JiraHelper::Misc
      include ::JiraHelper::Git
      include ::JiraHelper::Jira

      PROJECT_PATTERN          = /(?<project>[a-zA-Z0-9]{1,10})/
      RELEASE_PATTERN          = /(?<release>[A-Z0-9.\s]{1,10})/
      ISSUE_PATTERN            = /(?<issue>#{PROJECT_PATTERN}-[0-9]{1,5}+)/
      ISSUES_PATTERN           = /(?<issues>(#{PROJECT_PATTERN}[\S-][0-9]{1,5}\s*)+)/
      AFFECTS_VERSIONS_PATTERN = /"(?<affects_versions>[A-Z0-9,.\s]+)"/
      BRANCH_PATTERN           = /(?<branch>.+)/
      COMMIT_PATTERN           = /(?<commit>.+)/
      PRODUCTION_TYPE          = 'Store'


      route(%r{.*jiraquery\s(.*)}i,
        :jira_query,
        command: false,
        help: {t('help.jira_query.syntax') => t('help.jira_query.desc')}
      )

      route(%r{.*jira\s#{ISSUE_PATTERN}}i,
        :details,
        command: false,
        help: {t('help.details.syntax') => t('help.details.desc')}
      )

      route(%r{.*jirafull\s#{ISSUE_PATTERN}}i,
        :details_full,
        command: false,
        help: {t('help.detailsfull.syntax') => t('help.detailsfull.desc')}
      )

      route(%r{.*jiralist\s\[\s*#{ISSUES_PATTERN}\s*\]}i,
            :details_list,
            command: false,
            help: {t('help.detailslist.syntax') => t('help.detailslist.desc')}
      )

      route(%r{.*jiralistfull\s\[#{ISSUES_PATTERN}\]}i,
            :details_list_full,
            command: false,
            help: {t('help.detailslistfull.syntax') => t('help.detailslistfull.desc')}
      )

      route(%r{.*jirapr\s#{ISSUE_PATTERN}}i,
        :details_pr,
        command: false,
        help: {t('help.jirapr.syntax') => t('help.jirapr.desc')}
      )

      route(%r{.*jira_description\s#{ISSUE_PATTERN}}i,
        :jira_description,
        command: false,
        help: {t('help.jira_description.syntax') => t('help.jira_description.desc')}
      )

      route(%r{.*cherry_pick\s+#{BRANCH_PATTERN}\s#{ISSUE_PATTERN}}i,
        :cherry_pick,
        command: true,
        help: {t('help.cherry_pick.syntax') => t('help.cherry_pick.desc')}
      )

      route(%r{.*cherry_pick_do_it\s+#{BRANCH_PATTERN}\s#{ISSUE_PATTERN}}i,
        :cherry_pick_do_it,
        command: true,
        help: {t('help.cherry_pick_do_it.syntax') => t('help.cherry_pick_do_it.desc')}
      )

      route(%r{.*cherry_pick_commit\s+#{PROJECT_PATTERN}\s#{BRANCH_PATTERN}\s#{COMMIT_PATTERN}}i,
        :cherry_pick_commit,
        command: true,
        help: {t('help.cherry_pick_commit.syntax') => t('help.cherry_pick_commit.desc')}
      )

      route(%r{.*jirarelease\s#{RELEASE_PATTERN}}i,
        :release_list_all,
        command: true,
        help: {t('help.jirarelease.syntax') => t('help.jirarelease.desc')}
      )

      route(%r{.*jirareleasecp\s#{RELEASE_PATTERN}}i,
        :release_list_no_closed,
        command: true,
        help: {t('help.jirareleasecp.syntax') => t('help.jirareleasecp.desc')}
      )

      route(%r{.*create_release_tickets\s#{PROJECT_PATTERN}\s#{RELEASE_PATTERN}}i,
        :create_release_tickets,
        command: true,
        help: {t('help.release_tickets.syntax') => t('help.release_tickets.desc')}
      )

      route(%r{.*update_crash_counts}i,
        :update_top_jira_crashes,
        command: true,
        help: {t('help.crash_counts.syntax') => t('help.crash_counts.desc')}
      )

      route(%r{.*list_prod_affects_versions}i,
        :list_prod_affects_versions,
        command: true,
        help: {t('help.bot_configs.list_syntax') => t('help.bot_configs.list_desc')}
      )

      route(%r{.*update_prod_affects_versions}i,
        :update_prod_affects_versions,
        command: true,
        help: {t('help.bot_configs.update_prod_affects_versions_syntax') => t('help.bot_configs.update_prod_affects_versions_desc')}
      )

      route(%r{.*cleanup_crash_issues\s#{PROJECT_PATTERN}}i,
        :clean_up_crash_bugs,
        command: true,
        help: {t('help.cleanup_crash_issues.syntax') => t('help.cleanup_crash_issues.desc')}
      )

      route(%r{.*cleanup_ks_issues\s#{PROJECT_PATTERN}}i,
        :cleanup_ks_issues,
        command: true,
        help: {t('help.cleanup_ks_issues.syntax') => t('help.cleanup_ks_issues.desc')}
      )

      route(%r{.*list_filter_configs}i,
        :list_filter_configs,
        command: true,
        help: {t('help.filter_configs.syntax') => t('help.filter_configs.desc')}
      )

      # Anything coming from a bot and has data[username] field
      # see message_handler.rb:158
      route(/(.*New Crash Group for.*)/,
        :create_or_comment,
        command: false
      )

      route(%r{.*update_bots}i,
        :update_bots,
        command: true,
      )


      def cleanup_ks_issues(response)
        project = response.match_data['project'].strip
        issues = ks_error_issues_to_cleanup(project)
        close_comment = "Automatically closing since it is Known Shippable."
        closed_num = 0
        closed_issues = []
        error_info = ""

        if issues.length == 0
          response.reply("No issues need to be cleaned up.")
        else
          issues.each do |issue|
            begin
              close_issue(project, issue, close_comment)
              closed_issues.push("#{issue.key}")
              closed_num += 1
            rescue => ex
              error_info += "An error occurred when trying to close #{issue.key}: #{ex.message}\n"
            end
          end
          response.reply("The following #{closed_num} KS issues were closed successfully:\n #{closed_issues.to_s}")
          if (error_info != "")
            response.reply("#{error_info}")
          end
        end
      end

      def clean_up_crash_bugs(response)
        # 1. Get list of versions that do not include: master, rewrap or latest prod release.
        project = response.match_data['project'].strip.downcase
        projects = eval(config.jira.projects)
        real_project = projects[project]
        exclude_versions = exclude_crash_versions(real_project)
        # 2. Get list of crash issues to clean up
        issues = crash_issues_to_clean_up(real_project)
        # 3. Close crash issues that have not occurred in master, rewrap
        #    or latest production release.
        close_comment = "Automatically closing since it does not occur in current master,
                        rewrap or latest production release."
        closed_num = 0
        closed_issues = []
        error_info = ""

        if issues.length == 0
          response.reply("No issues need to be cleaned up.")
        else 
          issues.each do |issue|
            begin
              affected_version = all_affected_version(issue)
              if (!contain_exclude_versions(affected_version, exclude_versions))
                close_issue(project, issue, close_comment)
                closed_issues.push("#{issue.key}")
                closed_num += 1
              end
            rescue => ex
              error_info = "An error occurred when trying to close #{issue.key}: #{ex.message}"
              break
            end
          end
          response.reply("The following #{closed_num} crash issues were closed successfully:\n #{closed_issues.to_s}")
          if (error_info != "")
            response.reply("#{error_info}")
          end
        end
      end

      def create_release_tickets(response)
        json = File.read("#{Dir.pwd}/../lita_config.json")
        data = JSON.parse(json)

        tickets = data['tickets']
        project = response.match_data['project']
        affects_version = response.match_data['release']

        tickets.each do |ticket|
          if project == ticket['project']
            summary = ticket['task']
            description = ticket['description']
            watchers = ticket['watchers']
            assignee = ticket['assignee']

            begin
              new_issue = create_issue(project, summary, description, 'task', affects_version, assignee, watchers)
              log.info "#{t('hockeyappissues.new_release_ticket',
                            release: "#{project} #{affects_version}",
                            task: summary,
                            site: config.jira.site,
                            key: new_issue.key)}"
              response.reply(t('hockeyappissues.new_release_ticket',
                               release: "#{project} #{affects_version}",
                               task: summary,
                               site: config.jira.site,
                               key: new_issue.key))
            rescue Exception => e
              log.error "#{t('hockeyappissues.create_tickets_issue', e: e)}"
              return response.reply(t('hockeyappissues.create_tickets_issue', e: e))
            end
          end
        end
      end

      def get_project_from_issue(issue)
        return issue.split('-')[0]
      end

      def create_commit_list(commits)
        commit_list = ""
        commits.reverse_each do |commit|
          commit_list += commit + "\n"
        end
        return commit_list
      end

      def create_commit_with_summary(commit, location)
        commit_info = get_log_info(commit, location)
        #Running from the command line can make non-ascii characters
        #Remove them so we can send them
        #Check out http://stackoverflow.com/questions/1268289/how-to-get-rid-of-non-ascii-characters-in-ruby
        # See String#encode documentation
        encoding_options = {
          :invalid           => :replace,  # Replace invalid byte sequences
          :undef             => :replace,  # Replace anything not defined in ASCII
          :replace           => '',        # Use a blank for those replacements
          :UNIVERSAL_NEWLINE_DECORATOR => true       # Always break lines with \n
        }
        return commit_info.encode(Encoding.find('ASCII'), encoding_options).inspect
      end

      def create_commit_list_with_summary(commits, location)
        commit_list = ""
        commits.reverse_each do |commit|
          commit_list += create_commit_with_summary(commit, location) + "\n\n"
        end
        return commit_list
      end

      def cherry_pick(response)
        branch = response.match_data['branch'].strip
        issue  = fetch_issue(response.match_data['issue'])
        repo   = get_project_from_issue(response.match_data['project'])

        repos_dir = File.join(Dir.home, 'repos')
        repo_location = "#{repos_dir}/#{repo}/"

        response.reply(t('git.fetching'))

        fetch_repo(repo, repos_dir, repo_location)
        change_and_update_branch('master', repo_location)
        repositories = get_jira_repos(issue)

        if not branch_exists(branch, repo_location)
          response.reply(t('git.no_branch'))
          return
        end

        change_and_update_branch(branch, repo_location)
        commits = get_commits_to_cherry_pick(repositories, branch, repo_location)

        if commits['branch'].empty? and commits['picked'].empty? and commits['to_pick'].empty?
          response.reply(t('error.no_commits'))
          return
        end

        commits_in_branch = create_commit_list(commits['branch'])
        if not commits_in_branch.empty?
          response.reply(t('git.branched', commits: commits_in_branch))
        end

        commits_cherry_picked = create_commit_list(commits['picked'])
        if commits_cherry_picked != ""
          response.reply(t('git.picked', commits: commits_cherry_picked))
        end

        commits_to_cherry_pick = create_commit_list_with_summary(commits['to_pick'], repo_location)
        if commits_to_cherry_pick != ""
          response.reply(t('git.cherry_pick', commits: commits_to_cherry_pick))
        end
      end

      def cherry_pick_do_it(response)
        branch = response.match_data['branch'].strip
        issue  = fetch_issue(response.match_data['issue'])
        repo   = get_project_from_issue(response.match_data['issue'])

        repos_dir = File.join(Dir.home, 'repos')
        repo_location = "#{repos_dir}/#{repo}/"

        response.reply(t('git.fetching'))
        set_git_name(response.user.name, repo_location)
        set_git_email(response.user.mention_name + "@anki.com", repo_location)

        fetch_repo(repo, repos_dir, repo_location)
        change_and_update_branch('master', repo_location)
        repositories = get_jira_repos(issue)

        if not branch_exists(branch, repo_location)
          response.reply(t('git.no_branch'))
          return
        end

        change_and_update_branch(branch, repo_location)
        commits = get_commits_to_cherry_pick(repositories, branch, repo_location)

        if commits['branch'].empty? and commits['picked'].empty? and commits['to_pick'].empty?
          response.reply(t('error.no_commits'))
          return
        end

        commits_in_branch = create_commit_list(commits['branch'])
        if not commits_in_branch.empty?
          response.reply(t('git.branched', commits: commits_in_branch))
        end

        commits_cherry_picked = create_commit_list(commits['picked'])
        if commits_cherry_picked != ""
          response.reply(t('git.picked', commits: commits_cherry_picked))
        end

        commits_to_cherry_pick = create_commit_list_with_summary(commits['to_pick'], repo_location)
        if commits_to_cherry_pick != ""
          response.reply(t('git.cherry_pick', commits: commits_to_cherry_pick))
        end

        if not do_cherry_pick_list(commits['to_pick'].reverse, branch, repo_location)
          response.reply(t('git.cherry_pick_failure'))
        else
          do_git_push(branch, repo_location)
          response.reply(t('git.cherry_pick_success'))
        end
      end

      def cherry_pick_commit(response)
        branch = response.match_data['branch'].strip
        commit = response.match_data['commit']
        repo   = response.match_data['project']

        repos_dir = File.join(Dir.home, 'repos')
        repo_location = "#{repos_dir}/#{repo}/"

        response.reply(t('git.fetching'))

        fetch_repo(repo, repos_dir, repo_location)
        change_and_update_branch('master', repo_location)

        if not branch_exists(branch, repo_location)
          response.reply(t('git.no_branch'))
          return
        end

        change_and_update_branch(branch, repo_location)
        commit_to_cherry_pick = create_commit_with_summary(commit, repo_location)
        if commit_to_cherry_pick != ""
          response.reply(t('git.cherry_pick', commits: commit_to_cherry_pick))
        end

        if not do_cherry_pick(commit, branch, repo_location)
          response.reply(t('git.cherry_pick_failure'))
        else
          do_git_push(branch, repo_location)
          response.reply(t('git.cherry_pick_success'))
        end

      end

      def list_prod_affects_versions(response)
        if config.jira.production_version.nil?
          config.jira.production_version = update_production_app_version()
        end
        log.info "The current production versions are: #{config.jira.production_version}"
        response.reply("Hockeybot will ignore any reports for issues affecting #{config.jira.production_version}" + 
                       " or older.\nIf versions seem out of date, run `update_prod_affects_versions`")
      end

      def details(response)
        issue = fetch_issue(response.match_data['issue'])
        return response.reply(t('error.request')) unless issue
        response.reply(format_issue(issue))
      end

      def details_full(response)
        issue = fetch_issue(response.match_data['issue'])
        return response.reply(t('error.request')) unless issue
        response.reply(format_issue_full(issue))
      end

      def details_list(response)
        issues = response.match_data['issues'].split(' ')
        issues.each do |i|
          issue = fetch_issue(i.strip)
          return response.reply(t('error.request')) unless issue
          response.reply(format_issue(issue))
        end
      end

      def details_list_full(response)
        issues = response.match_data['issues'].split(' ')
        issues.each do |i|
          issue = fetch_issue(i.strip)
          return response.reply(t('error.request')) unless issue
          response.reply(format_issue_full(issue))
        end
      end

      def details_pr(response)
        issue = fetch_issue(response.match_data['issue'])
        return response.reply(t('error.request')) unless issue

        pull_requests = get_jira_pull_requests(issue)
        response.reply(format_issue_pr(pull_requests, issue))
      end

      def update_bots(response)
        if config.jira.allowed_update_users.include? response.user.id
          response.reply(t('request.executing'))
          log_trigger_info(response.user.name)
          cmd_process = `sudo start hockeybot-updater`
        else
          response.reply("User ID #{response.user.id} is not in the approved list to update the bots")
        end
      end

      def jira_query(response)
        crash_name = response.matches.join("").strip
        crashes_filter = eval(config.jira.crashes_filter)
        crash_id = 0
        if crashes_filter.nil?
          response.reply("No input data in CRASH_FILTER env!")
          return
        else
          crash_id = crashes_filter[crash_name]
          if crash_id.nil?
            response.reply("Invalid filter! The crash filter should be #{crashes_filter.keys.join(", ")}")
            return
          end
        end
        issues = fetch_issues_by_filter_id(crash_id)
        if issues.size > 0
          list = "jiralist ["
          issues.each do |issue|
            list += "#{issue.key} "
          end
          list += "]"
          response.reply(list)
        else
          response.reply("No issues were found!")
        end
      end

      def jira_description(response)
        issue = fetch_issue(response.match_data['issue'])
        return response.reply(t('error.request')) unless issue
        response.reply(format_issue_description(issue))
      end

      def jql_issue_list(response, jql)
        log.info jql
        issues = fetch_issues(jql)
        return response.reply(t('error.request')) unless issues
        issue_summary = ""
        issues.each do |issue|
          issue_summary += format_issue_list(issue) + "\n"
        end
        response.reply(issue_summary)
      end

      def get_project_from_version(version)
        return version.split[0]
      end

      def release_list_all(response)
        project = get_project_from_version(response.match_data['release'])
        jql ="'Project' = '" + project + "' AND " +
             "'fixVersion' = '" + response.match_data['release'] + "'"
        jql_issue_list(response, jql)
      end

      def release_list_no_closed(response)
        project = get_project_from_version(response.match_data['release'])
        jql ="'Project' = '" + project + "' AND " +
             "'fixVersion' = '" + response.match_data['release'] + "' AND " +
             "status in ('Test Ready', 'Test Verified (Master)')"
        jql_issue_list(response, jql)
      end

      def create_or_comment(response)
        message_array = response.matches
        message_string = message_array[0].to_s
        message_string = message_string[2..-3]
        message_string = message_string.gsub(/\\\\\\"/) { "'" } #change quoted text to use single quotes
        message_string.delete! '\\' # remove all the extra '/' characters
        puts message_string

        data = MultiJson.load(message_string)
        text = data['text']
        text = text.gsub('<', '')
                   .gsub('>', '')
                   .gsub('u003c', '')
                   .gsub('u003e', '')
                   .gsub('|', ' ')
                   .gsub('%7C', ' ')
                   .gsub(' View on HockeyApp', '')
                   .gsub(' View on HockeyApp', '')

        icons = data['icons']

        attachment_fields = Array(data['attachments']).map do |attachment|
          attachment['fields']
        end

        platform = attachment_fields[0][0]['value']
        release_type = attachment_fields[0][1]['value']
        version = attachment_fields[0][2]['value']
        location = attachment_fields[0][3]['value']
        reason = attachment_fields[0][4]['value']

        hockeyapp_url = text.rpartition(' ').last
        projects = eval(config.jira.projects)
        project_transitions = eval(config.jira.project_open_transitions)
        jira_project = projects[text.split(" ")[4].split("-")[0]]
        location_search = jql_search_formatting(location)
        location_summary = jira_summary_formatting("Fix crash in #{location}")
        location_desc = jira_description_formatting(location)
        reason_search = jql_search_formatting(reason)
        reason_desc = jira_description_formatting(reason)

        version = version.split("(")[0].rstrip
        begin
          affects_version = Gem::Version.new(version)
        rescue
          log.error "Someone is playing with the invalid '#{affects_version}' release build."
          return response.reply(t('hockeyappissues.invalid_release', release: affects_version))
        end
           
        check_and_update_prod_app_version()
        config.jira.production_version.split(",").each do |exclude|
          exclude_project_name = exclude.split(" ")[0]
          exclude_gem_version  = Gem::Version.new(exclude.split(" ")[1])
          if affects_version <= exclude_gem_version and exclude_project_name == jira_project
            log.error "The #{affects_version} release is excluded from bot processing, ignoring."
            return response.reply(t('release.excluded', release: affects_version))
          end
        end

        afv_str = "#{affects_version}".split('.')
        affects_version = "#{jira_project} #{afv_str[0]}.#{afv_str[1]}.#{afv_str[2]}"

        
        # to prevent duplicates of random memory addresses (e.g. "fault addr eee349d0", "fault addr 00w00300")
        unless config.jira.str_excludes.nil?
          config.jira.str_excludes.split(",").each do |str|
            if location_search.include? str
              location_search = location_search.gsub(/#{str}.+/, "#{str}")
            end
            if reason_search.include? str
              reason_search = reason_search.gsub(/#{str}.+/, "#{str}")
            end
          end
        end

        log.info
        log.info "text               = #{text}"
        log.info "hockeyapp_url      = #{hockeyapp_url}"
        log.info "platform           = #{platform}"
        #log.info "attachement_fields = #{attachment_fields}"
        log.info "release_type       = #{release_type}"
        log.info "version            = #{version}"
        log.info "jira_project       = #{jira_project}"
        log.info "location           = #{location}"
        log.info "location_search    = #{location_search}"
        log.info "location_summary   = #{location_summary}"
        log.info "location_desc      = #{location_desc}"
        log.info "reason             = #{reason}"
        log.info "reason_search      = #{reason_search}"
        log.info "reason_desc        = #{reason_desc}"
        log.info "affects_version    = #{affects_version}"

        # look for duplicates in JIRA
        jql = "project = #{jira_project}
                AND summary ~ '#{location_search}'
                AND description ~ 'reason: #{reason_search}'
                ORDER BY status ASC"
        log.info "jql                = #{jql}"
        issues = fetch_issues(jql)
        if issues.empty?
          if !location_search[/\w/].nil?
            issues_jql = handle_special_jql(jira_project, location_search)
            issues = fetch_issues(issues_jql)
          end
        end

        # create a new JIRA ticket if no issues are found
        apprun = get_hockeyapp_crash_apprun(hockeyapp_url)
        apprun_text = '@apprunbot apprun '
        if release_type != PRODUCTION_TYPE
          begin
            new_issue = create_issue(jira_project,
                                     location_summary,
                                     "#{text}
                                            \n\n*Location:* {code}#{location_desc}{code}
                                            \n\n*Reason:* {code}#{reason_desc}{code}
                                            \n\n*Platform:* #{platform}
                                            \n\n*Release Type:* #{release_type}
                                            \n\n*Version:* #{version}
                                            \n\n#{apprun_text}#{apprun}",
                                     "crash",
                                     affects_version,
                                     nil, nil) unless issues.size > 0
          rescue
            log.error("The '#{affects_version}' release is not defined in JIRA.
                      '#{affects_version}' crashes will not be processed until that is done.")
            return response.reply(t('hockeyappissues.affects_version_undef_jira', release: affects_version))
          end
          hockeyapp_jira_link(new_issue, hockeyapp_url) unless issues.size > 0
          label_issue(new_issue, "triage") unless issues.size > 0
          log.info "#{t('hockeyappissues.new', site: config.jira.site, key: new_issue.key)}" unless issues.size > 0
          return response.reply(t('hockeyappissues.new', site: config.jira.site, key: new_issue.key)) unless issues.size > 0
        end

        if issues.size > 0
          # check fix_version is nil or fix_version is empty in Jira
          if issues.first.fields['fixVersions'][0] != nil && issues.first.fields['fixVersions'][0].length() > 0
            fix_version = Gem::Version.new(issues.first.fields['fixVersions'][0]['name'].split(' ')[1])
          else
            log.info("Fix version is missing")
            fix_version = Gem::Version.new(issues.first.fields['fixVersions'][0])
          end

          # re-open ticket logic
          log.info "---------------------------------------"
          log.info "#{issues.first.fields['status']['name']}"
          if (issues.first.fields['status']['name'] == 'Closed') && (issues.last.fields['status']['name'] != 'To Do')
            if issues.first.fields['resolution']['name'] == 'Cannot Reproduce'
              log.info "#{issues.first.fields['resolution']['name']}"
              log.info "---------------------------------------"
              transition = issues.first.transitions.build()
              transition.save(:transition => {:id => "#{project_transitions[jira_project]}"})
              response.reply("Re-opening #{issues.first.key}")
              issues = fetch_issues(jql)
            elsif ((issues.first.fields['resolution']['name'] == 'Fixed/Merged') ||
             (issues.first.fields['resolution']['name'] == 'Task Completed') ||
             (issues.first.fields['resolution']['name'] == 'Done')) &&
             (fix_version < Gem::Version.new(version))
                log.info "#{issues.first.fields['resolution']['name']}"
                log.info "#{fix_version}"
                log.info "#{Gem::Version.new(version)}"
                log.info "---------------------------------------"
                transition = issues.first.transitions.build()
                transition.save(:transition => {:id => "#{project_transitions[jira_project]}"})
                response.reply("Re-opening #{issues.first.key}")
                issues = fetch_issues(jql)
            end
          end
          log.info duplicate_issue(issues)
          response.reply(duplicate_issue(issues))

          # comment on all existing non Closed tickets if they exist,
          comment_string = "#{text}
                                \nplatform: #{platform}
                                \nrelease_type: #{release_type}
                                \nversion: #{version}
                                \n#{apprun_text}#{apprun}
                                \nlocation: {noformat}#{location_desc}{noformat}
                                \nreason: {noformat}#{reason_desc}{noformat}"
          comment_issue(response, issues, comment_string, affects_version, hockeyapp_url)
        else
          response.reply("No issues were found in #{PRODUCTION_TYPE.upcase} release type.")
        end
      end

      # update JIRA with top 10 hockeyapp crash counts
      def update_top_jira_crashes(response)
        sort_criteria = "crash_reasons?sort=number_of_crashes&page=1&order=desc"
        platform_urls = Array.new
        ticket_keys_list = Array.new
        all_master_ids = get_all_master_ids()
        all_master_ids.each do |app, versions|
          versions.each do |version|
            platform_urls.push("#{config.jira.hockeyapp_url}/#{app}/app_versions/#{version}")
          end
        end
        log.info "hockeyapp_urls: #{platform_urls}"

        platform_urls.each do |platform_url|
          crash_ids_counts = Hash.new
          count = 0
          http = Curl.get("#{platform_url}/#{sort_criteria}") do|http|
            http.headers['X-HockeyAppToken'] = "#{config.jira.hockeyapp_token}"
          end
          data = JSON.parse(http.body_str)
          data['crash_reasons'].each do |id|
            crash_ids_counts[id['id'].to_s] = id['number_of_crashes'].to_s
            count += 1
            if count == config.jira.hockeyapp_topN_crashes.to_i
              break;
            end
          end
          log.info "crash_ids_counts: #{crash_ids_counts}"

          crash_ids_counts.each do |crash_id, crash_count|
            url = "#{platform_url}/crash_reasons/#{crash_id}"
            http = Curl.get(url) do|http|
              http.headers['X-HockeyAppToken'] = "#{config.jira.hockeyapp_token}"
            end
            data = JSON.parse(http.body_str)
            # prevent the error when crash_reason does not have ticket_urls key
            if data['crash_reason'].key?('ticket_urls')
              ticket_key = data['crash_reason']['ticket_urls'][0].split('/').last
              if ticket_keys_list.include?(ticket_key)
                crash_count_old = current_crash_count(ticket_key)
                crash_count = crash_count_old.to_i + crash_count.to_i
              else
                ticket_keys_list.push(ticket_key)
              end
              log.info "ticket-count: #{ticket_key}:#{crash_count}"

              issue = fetch_issue(ticket_key)
              issue.save!(fields: { customfield_11602: crash_count.to_f })
              response.reply("Updated #{data['crash_reason']['ticket_urls'][0]} to #{crash_count} crashes.")
            end
          end
        end
      end

      def list_filter_configs(response)
        crashes_filter = eval(config.jira.crashes_filter)
        crashes_filter.each do |filtered_name, filtered_id|
          crash_desc = "jira filter #{filtered_id} = `jiraquery #{filtered_name}`"
          response.reply(crash_desc)
        end
      end
      

##############################################
################## HELPERS ###################
##############################################

      # exclude special characters that conflict with JQL queries
      def jql_search_formatting(message)
        message = message.gsub('&lt;', '<')
                         .gsub('u0026lt;', '<')
                         .gsub('&gt;', '>')
                         .gsub('u0026gt;', '>')
                         .gsub('&amp;', '&')
                         .gsub('u0026amp;', '&')
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
                         .gsub(/\\/) { '\\\\' }
                         .gsub("'", "\\\\'")

        message = message[0..230]
      end

      # max 250 JIRA summary length
      def jira_summary_formatting(message)
        message = message.gsub('&lt;', '<')
                         .gsub('u0026lt;', '<')
                         .gsub('&gt;', '>')
                         .gsub('u0026gt;', '>')
                         .gsub('&amp;', '&')
                         .gsub('u0026amp;', '&')

        message = message[0..250]
      end

      def jira_description_formatting(message)
        message = message.gsub('&lt;', '<')
                         .gsub('u0026lt;', '<')
                         .gsub('&gt;', '>')
                         .gsub('u0026gt;', '>')
                         .gsub('&amp;', '&')
                         .gsub('u0026amp;', '&')
      end

      def comment_issue(response, issues, comment_string, affects_version, hockeyapp_url)
        issues.map { |issue|
          if (issue.fields['status']['name'] != 'Closed') ||
             (issue.fields['status']['name'] == 'Closed' &&
             ((issue.fields['resolution']['name'] != 'Duplicate') &&
             (issue.fields['resolution']['name'] != 'As Designed') &&
             (issue.fields['resolution']['name'] != 'Invalid') &&
             (issue.fields['resolution']['name'] != 'Know Shippable') &&
             (issue.fields['resolution']['name'] != "Won't Do")))
                log.info comment_string
                comment = issue.comments.build
                comment.save!(body: comment_string)
                #label_issue(issue, label)
                add_affects_version(issue, affects_version)
                hockeyapp_jira_link(issue, hockeyapp_url)
                response.reply(t('comment.added', affects_version: affects_version, issue: issue.key))
          end
        }
      end

      # get apprun of crash
      def get_hockeyapp_crash_apprun(hockeyapp_url)
        hockeyapp_api_url = get_hockeyapp_api_url(hockeyapp_url)

        http = Curl.get(hockeyapp_api_url) do|http|
          http.headers['X-HockeyAppToken'] = "#{config.jira.hockeyapp_token}"
        end
        data = JSON.parse(http.body_str)
        crash_id = data['crashes'][0]['id']
        hockeyapp_crash_url = "#{hockeyapp_api_url[/(.*?)crash_reasons/m, 1]}crashes/#{crash_id}"
        log.info "hockeyapp_crash_url: #{hockeyapp_crash_url}"

        http = Curl.get("#{hockeyapp_crash_url}?format=text") do|http|
          http.follow_location = true
          http.headers['X-HockeyAppToken'] = "#{config.jira.hockeyapp_token}"
        end

        body_str = http.body_str[/.*({.*)/m, 1]
        apprun = nil
        if body_str.nil?
          log.error "apprun: no apprun found in description"

          http = Curl.get("#{hockeyapp_crash_url}?format=log") do|http|
            http.follow_location = true
            http.headers['X-HockeyAppToken'] = "#{config.jira.hockeyapp_token}"
          end
          body_str = http.body_str[/.*apprun: ([A-Z0-9-]{1,36})/m, 1]
          if body_str.nil?
            apprun = "no apprun found"
            log.error "apprun: no apprun found in log"
          else
            apprun = body_str
            log.info "apprun: #{apprun}"
          end
        else
          data = JSON.parse(body_str)
          apprun = data['apprun']
          log.info "apprun: #{apprun}"
        end

        return apprun
      end

      # update hockey crash with JIRA url, status=0=OPEN
      def hockeyapp_jira_link(issue, hockeyapp_url)
        hockeyapp_api_url = get_hockeyapp_api_url(hockeyapp_url)

        #curl -F "status=0" -F "ticket_url=#{site}/browse/#{issue.key}" -H "X-HockeyAppToken: #{hockeyapp_token}" hockeyapp_api_url
        c = Curl::Easy.http_post("#{hockeyapp_api_url}",
            Curl::PostField.content('status', '0'),
            Curl::PostField.content('ticket_url', "#{config.jira.site}/browse/#{issue.key}")) do |curl|
              curl.headers['X-HockeyAppToken'] = "#{config.jira.hockeyapp_token}"
            end
        c.perform
      end

      def get_hockeyapp_api_url(hockeyapp_url)
        hockeyapp_url = hockeyapp_url.gsub('manage', 'api/2')

        http = Curl.get("#{config.jira.hockeyapp_url}") do|http|
          http.headers['X-HockeyAppToken'] = "#{config.jira.hockeyapp_token}"
        end

        hockapp_url_id = hockeyapp_url[/apps(.*?)crash_reasons/m, 1].gsub('/', '')
        api_url_id = nil

        data = JSON.parse(http.body_str)
        data['apps'].each do |app|
          if app['id'].to_s == hockapp_url_id.to_s
            api_url_id = app['public_identifier']
          end
        end

        hockeyapp_api_url = hockeyapp_url.gsub("#{hockapp_url_id}", "#{api_url_id}")
        log.info "hockeyapp_url: #{hockeyapp_api_url}"

        return hockeyapp_api_url
      end

      def ambient(response)
        return if invalid_ambient?(response)
        issue = fetch_issue(response.match_data['issue'], false)
        response.reply(format_issue(issue)) if issue
      end

      def check_and_update_prod_app_version()
        seconds_in_days = 86400.0
        days_since_last_check = (Time.now.to_i - config.jira.production_version_last_checked)/seconds_in_days
        
        if config.jira.production_version.nil? or days_since_last_check >= config.jira.production_version_update_freq_days          
          config.jira.production_version = update_production_app_version()
          config.jira.production_version_last_checked = Time.now.to_i
        end
      end

      def update_prod_affects_versions(response)
        config.jira.production_version = update_production_app_version()
        config.jira.production_version_last_checked = Time.now.to_i
        response.reply("App versions have been updated, and they are: #{config.jira.production_version}")
      end

      private

      def invalid_ambient?(response)
        response.message.command? || !config.jira.ambient || ignored?(response.user) || (config.jira.rooms && !config.jira.rooms.include?(response.message.source.room))
      end

      def ignored?(user)
        config.jira.ignore.include?(user.id) || config.jira.ignore.include?(user.mention_name) || config.jira.ignore.include?(user.name)
      end
      # rubocop:enable Metrics/AbcSize
    end
    # rubocop:enable Metrics/ClassLength
    Lita.register_handler(Jira)
  end
end
