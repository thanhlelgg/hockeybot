# Helper functions for lita-jira
module JiraHelper
  # Misc
  module Misc

    class JsonClient < JIRA::Client
      def get(path, headers = {})
        headers = {'Content-Type' => 'application/json'}.merge(headers)
        request(:get, path, nil, merge_default_headers(headers))
      end
    end

    def client
      JsonClient.new(
        username: config.jira.username,
        password: config.jira.password,
        site: config.jira.site,
        context_path: config.jira.context,
        auth_type: :basic,
        read_timeout: config.jira.read_timeout.to_i
      )
    end

    def log_trigger_info(username)
      current_time = Time.now.utc
      File.write('/tmp/trigger_info.log', "Triggered by: #{username} at: #{current_time}")
    end

  end
end
