require "simplecov"
require "coveralls"
require 'curb'
require 'webmock/rspec'
require 'timeout'

TIME_LIMIT = 60
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start { add_filter "/spec/" }

require 'lita-jira'
require "lita/rspec"

Lita.version_3_compatibility_mode = false

RSpec.configure do |config|
  config.before do
    registry.register_handler(Lita::Handlers::Jira)
    registry.register_handler(Lita::Handlers::Mode)
    registry.register_handler(Lita::Handlers::Common)
    registry.register_handler(Lita::Handlers::Git)
  end
  config.mock_with :rspec do |mocks|
    mocks.syntax = [:should, :expect]
    mocks.verify_partial_doubles = true
  end
  config.around(:each) do |example|
    Timeout::timeout(TIME_LIMIT) {
      example.run
    }
  end
end

def grab_request(result)
  allow(JIRA::Client).to receive(:new) { result }
end

def get_variables()
  json_data = Hash.new
  lita_filepath = File.expand_path("../../scripts/lita-hockeybot.conf", File.dirname(__FILE__))
  if File.exists?(lita_filepath)
    File.readlines(lita_filepath).each do |line|
      if line.start_with?("env")
        key_value = line.chomp.gsub("\"",'').split(" ", 2)[1]
        values = key_value.split("=", 2)
        json_data[values[0]] = values[1]
      end
    end
  else
    puts "lita-hockeybot file does not exist, please add it before run"
  end
  return json_data
end

########Git Helper###########
def commit_in_branch_command(commit, branch)
  return "git branch --contains #{commit} | grep #{branch}"
end

def cherry_picked_command(branch, commit)
  return "git rev-list --cherry #{branch}...master | grep =#{commit}"
end

def get_merged_commit_command(commit)
  return "git rev-list --parents --merges -n 1 #{commit} | grep #{commit}"
end

def get_parents_of_merge_commit_command(commit)
  return "git rev-list --parents -n 1 #{commit}"
end

def find_diverged_of_commits_command(commit_1, commit_2)
  return "git merge-base #{commit_1} #{commit_2}"
end

def get_commits_between_two_commits_command(commit_1, commit_2)
  return "git rev-list #{commit_1}...#{commit_2}"
end

def stub_run_git_command(command, location, return_value)
  allow_any_instance_of(JiraHelper::Git).to receive(:run_git_command)
  .with(command, location).and_return(return_value)
end
