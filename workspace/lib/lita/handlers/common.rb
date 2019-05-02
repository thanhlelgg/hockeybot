module Lita
  # Because we can.
  module Handlers
    # Main handler
    # rubocop:disable Metrics/ClassLength
    class Common < Handler

      config :jira do
        config :hockeyapp_token, required: true, type: String
        config :hockeyapp_url, required: true, type: String
        config :hockeyapp_topN_crashes, required: true, type: String
        config :username, required: true, type: String
        config :password, required: true, type: String
        config :site, required: true, type: String
        config :read_timeout, required: true, type: String
        config :components, required: false, type: String
        config :production_version, required: false, type: String
        config :production_version_last_checked, required: false, type: Integer, default: Time.now.to_i
        config :production_version_update_freq_days, required: false, type: Integer, default: 14
        config :str_excludes, required: false, type: String
        config :git_uri_od, required: true, type: String
        config :git_uri_cozmo, required: true, type: String
        config :teamcity_uri, required: true, type: String
        config :teamcity_info, required: true, type: Hash
        config :projects, required: true, type: String
        config :project_open_transitions, required: true, type: String
        config :project_close_transitions, required: true, type: String
        config :context, required: false, type: String, default: ''
        config :format, required: false, type: String, default: 'verbose'
        config :ambient, required: false, types: [TrueClass, FalseClass], default: false
        config :ignore, required: false, type: Array, default: []
        config :rooms, required: false, type: Array
        config :hockeyapp_master_app_ids, required: true, type: String
        config :close_ticket_timeout, required: true, type: String
        config :url_applestore_api, required: true, type: String
        config :url_googleplay_api, required: true, type: String
        config :package_apps, required: true, type: String
        config :max_results, required: true, type: String
        config :vip_category_column, required: true, type: String
        config :crashes_filter, required: true, type: String
        config :release_page_id, required: true, type: String
        config :ez_office_site, required: true, type: String
        config :ez_office_token, required: true, type: String
        config :update_script, required: false, type: String
        config :allowed_update_users, required: false, type: String
      end

      config :mode do
        config :mode_token, required: true, type: String
        config :mode_password, required: true, type: String
        config :mode_time_wait, required: true, type: String
        config :labels, required: true, type: String
        config :log_warning, required: true, type: String
        config :od_prod_url, required: true, type: String
        config :od_dev_url, required: true, type: String
        config :cozmo_prod_url, required: true, type: String
        config :cozmo_dev_url, required: true, type: String
        config :email_username, required: true, type: String
        config :email_password, required: true, type: String
        config :od_prod_occurence, required: true, type: String
        config :od_dev_occurence, required: true, type: String
        config :cozmo_prod_occurence, required: true, type: String
        config :cozmo_dev_occurence, required: true, type: String
        config :to_email, required: true, type: String
        config :cc_email, required: true, type: String
        config :od_dev_url_error, required: true, type: String
        config :cozmo_dev_url_error, required: true, type: String
        config :mode_report_timeout, required: true, type: String
        config :dev_das_version_url, required: true, type: String
        config :prod_das_version_url, required: true, type: String
        config :beta_das_version_url, required: true, type: String
        config :das_table_name, required: true, type: String
        config :query_timeout, required: true, type: String
        config :vector_events, required: true, type: String
      end

      config :git do
        config :git_token, required: true, type: String
        config :git_api_uri_vector, required: true, type: String
      end

    end
    Lita.register_handler(Common)
  end
end
