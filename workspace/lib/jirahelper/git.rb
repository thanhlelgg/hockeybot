module JiraHelper
  # Jira
  module Git
    include ::JiraHelper::Issue
    include ::JiraHelper::Misc
############################################################################################
# Direct Git commands
############################################################################################       
    def run_git_command(command, location)
      log.info "command  : cd #{location} && #{command}"
      result = `cd #{location} && #{command}`
      return result
    end

    def cherry_picked(branch, commit, location)
      #This will list all commits from master and branch and show the cherry picked ones as
      #'=HASH'
      #We grep for this information to see if it has been cherry-picked
      result = run_git_command("git rev-list --cherry #{branch}...master | grep =#{commit}", location)
      if result == ""
        return false
      end
      return true
    end

    def branch_exists(branch, location)
      #Looks at all remote branchs and sees if the branch exists
      result = run_git_command("git branch -r | grep #{branch}", location)
      if result == ""
        return false
      end
      return true
    end

    def commit_in_branch(commit, branch, location)
      #Looks at all branchs to see if this commits exists and then see if it's in the given branch
      result = run_git_command("git branch --contains #{commit} | grep #{branch}", location)
      if result != ""
        return true
      end
      return false
    end

    def set_git_name(username, location)
      run_git_command("git config user.name \"#{username}\"", location)
    end

    def set_git_email(email, location)
      run_git_command("git config user.email \"#{email}\"", location)
    end

    def get_merged_commit(commit, location)
      #List all commits which have the given hash and are merges i.e. more than 1 parent
      #If the commits is listed here it is a merge and return the parents
      return run_git_command("git rev-list --parents --merges -n 1 #{commit} | grep #{commit}",
                             location)
    end


    def get_merged_commit(commit, location)
      #List all commits which have the given hash and are merges i.e. more than 1 parent
      #If the commits is listed here it is a merge and return the parents
      return run_git_command("git rev-list --parents --merges -n 1 #{commit} | grep #{commit}",
                             location)
    end

    def try_cherry_pick(commit, location)
      return run_git_command("git cherry-pick -s -x #{commit}", location)
    end


    def git_push(branch, location)
      run_git_command("git push origin #{branch}", location)
    end

    def do_cherry_pick(commit, branch, location)
      cherry_pick_status = try_cherry_pick(commit, location)
      log.info cherry_pick_status
      if not $?.success?
        run_git_command("git reset --hard origin #{branch}", location)
        return false
      end
      return true
    end

    def do_cherry_pick_list(commit_list, branch, location)
      commit_list.each do |commit|
        if not do_cherry_pick(commit, branch, location)
          return false
        end
      end
      return true
    end

    def do_git_push(branch, location)
      run_git_command("git push origin #{branch}", location)
    end

    def change_and_update_branch(branch, location)
      run_git_command("git reset --hard", location)
      result = run_git_command("git checkout #{branch}", location)
      result = run_git_command("git pull -p origin #{branch}", location)
      log.info "```#{result}```"
    end

    def get_log_info(commit, location)
      #Get the first line of commit information
      return run_git_command("git --no-pager log --pretty=oneline -n 1 #{commit}", location)
    end

    def fetch_repo(repo, repos_dir, location)
      #Get the repo information and if it has not been pulled down, pull it down
      Dir.mkdir(repos_dir) unless File.exists? File.expand_path("#{repos_dir}")

      if File.exists? File.expand_path("#{repos_dir}/#{repo}")
        run_git_command("git fetch -p origin master", location)
      else
        repo_uri = git_uri(repo)
        run_git_command("git clone #{repo_uri} #{repo}", location)
      end
    end

    def commits_in_merge(commit, location)
      #This finds all commits which have been merged into master or the commit's branch

      #Get the two parents of this merge
      result = run_git_command("git rev-list --parents -n 1 #{commit}", location)
      log.info result
      parents = result.split(' ')
      log.info parents

      #Find where these two parents had diverged.  This is the starting point
      merge_base = run_git_command("git merge-base #{parents[1]} #{parents[2]}", location)
      merge_base = merge_base.strip
      log.info merge_base

      #Find all commits from the start to the SECOND parent, which will be all commits
      #merged into this branch
      to_merge = run_git_command("git rev-list #{merge_base}...#{parents[2]}", location)
      log.info to_merge

      return to_merge.split
    end

############################################################################################
# Git helper functions
############################################################################################       

    def get_commits_to_cherry_pick(repositories, branch, location)
      commits = Hash.new
      commits['branch'] = Array.new
      commits['picked'] = Array.new
      commits['to_pick'] = Array.new
      all_commits = ""
      commits_to_cherry_pick = get_jira_commits_in_master(repositories, location)
      commits_to_cherry_pick.each do |commit|
        all_commits += commit + "\n"
        if commit_in_branch(commit, branch, location)
          commits['branch'].push(commit)
          next
        end

        if cherry_picked(branch, commit, location)
            commits['picked'].push(commit)
          next
        end

        merged_commit = get_merged_commit(commit, location)
        #This is a merged commit
        #We need to find all effected commits needed to cherry-pick
        if merged_commit != ""
          commits_in_merge(merged_commit, location).each do |merge_commit|
            if not commits['to_pick'].include?(merge_commit)
              commits['to_pick'].push(merge_commit)
            end
          end
        else #not a merge
          if not commits['to_pick'].include?(commit)
            commits['to_pick'].push(commit);
          end
        end
      end
      log.info "#{all_commits}"
      return commits
    end

    def git_uri(repo)
      git_uri = ""
      if repo == "OD"
        git_uri = config.jira.git_uri_od
      elsif repo == "COZMO"
        git_uri = config.jira.git_uri_cozmo
      end
      log.info "repo_uri : #{git_uri}"
      return git_uri
    end


############################################################################################
# Jira functions for git interface
############################################################################################       

    def get_jira_commits_in_master(repositories, location)
      commits_to_cherry_pick = Array.new
      repositories.each do |repository|
        repository['commits'].each do |commit|
          if commit_in_branch(commit['id'], "master", location)
            log.info "#{commit['id']}"
            commits_to_cherry_pick.push(commit['id'])
          end
        end
      end
      return commits_to_cherry_pick
    end

    def get_jira_pull_requests(issue)
        dev_info = fetch_dev_info(issue)
        pr_json = JSON.parse(dev_info)
        return pr_json['detail'][0]['pullRequests']
    end

    def get_jira_repos(issue)
        repo_info = fetch_repo_info(issue)
        repo_json = JSON.parse(repo_info)
        return repo_json['detail'][0]['repositories']
    end

  end
end
