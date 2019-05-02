Lita.configure do |config|
  # The name your robot will use.
  config.robot.name = "HockeyBot"

  # The locale code for the language to use.
  # config.robot.locale = :en

  # The severity of messages to log. Options are:
  # :debug, :info, :warn, :error, :fatal
  # Messages at the selected level and above will be logged.
  config.robot.log_level = :info

  config.http.port = 8081

  # An array of user IDs that are considered administrators. These users
  # the ability to add and remove other users from authorization groups.
  # What is considered a user ID will change depending on which adapter you use.
  # config.robot.admins = ["1", "2"]

  # The adapter you want to connect with. Make sure you've added the
  # appropriate gem to the Gemfile.
  # config.robot.adapter = :shell

  ## Example: Set options for the chosen adapter.
  # config.adapter.username = "myname"
  # config.adapter.password = "secret"

  ## Example: Set options for the Redis connection.
  # config.redis.host = "127.0.0.1"
  # config.redis.port = 1234

  ## Example: Set configuration for any loaded handlers. See the handler's
  ## documentation for options.
  # config.handlers.some_handler.some_config_key = "value"

  config.robot.adapter                                         = :slack
  config.adapters.slack.token                                  = ENV['SLACK_TOKEN']
  config.adapters.slack.unfurl_links                           = false
  config.handlers.common.jira.ambient                          = true

  config.handlers.common.jira.hockeyapp_token                  = ENV['HOCKEYAPP_TOKEN']
  config.handlers.common.jira.hockeyapp_url                    = ENV['HOCKEYAPP_URL']
  config.handlers.common.jira.hockeyapp_topN_crashes           = ENV['HOCKEYAPP_TOPN_CRASHES']
  config.handlers.common.jira.site                             = ENV['JIRA_SITE']
  config.handlers.common.jira.read_timeout                     = ENV['JIRA_TIMEOUT']
  config.handlers.common.jira.username                         = ENV['JIRA_USERNAME']
  config.handlers.common.jira.password                         = ENV['JIRA_PASSWORD']
  config.handlers.common.jira.components                       = ENV['JIRA_COMPONENTS']
  config.handlers.common.jira.projects                         = ENV['JIRA_PROJECTS']
  config.handlers.common.jira.project_open_transitions         = ENV['JIRA_PROJECT_OPEN_TRANSITIONS']
  config.handlers.common.jira.project_close_transitions        = ENV['JIRA_PROJECT_CLOSE_TRANSITIONS']
  config.handlers.common.jira.str_excludes                     = ENV['STR_EXCLUDES']
  config.handlers.common.jira.git_uri_od                       = ENV['GIT_URI_OD']
  config.handlers.common.jira.git_uri_cozmo                    = ENV['GIT_URI_COZMO']
  config.handlers.common.jira.teamcity_uri                     = ENV['TEAMCITY_URI']
  config.handlers.common.jira.teamcity_info                    = eval(ENV['TEAMCITY_INFO'])
  config.handlers.common.jira.hockeyapp_master_app_ids         = ENV['HOCKEYAPP_MASTER_APP_IDS']
  config.handlers.common.jira.close_ticket_timeout             = ENV['CLOSE_TICKET_TIMEOUT']
  config.handlers.common.jira.url_applestore_api               = ENV['URL_APPLESTORE_API']
  config.handlers.common.jira.url_googleplay_api               = ENV['URL_GOOGLEPLAY_API']
  config.handlers.common.jira.package_apps                     = ENV['PACKAGE_APPS']
  config.handlers.common.jira.max_results                      = ENV['JIRA_MAX_RESULTS']
  config.handlers.common.jira.vip_category_column              = ENV['VIP_CATEGORY_COLUMN']
  config.handlers.common.jira.crashes_filter                   = ENV['CRASHES_FILTER']
  config.handlers.common.jira.release_page_id                  = ENV['RELEASE_PAGE_ID']
  config.handlers.common.jira.ez_office_site                   = ENV['EZ_SITE']
  config.handlers.common.jira.ez_office_token                  = ENV['EZ_TOKEN']
  config.handlers.common.jira.update_script                    = ENV['UPDATE_SCRIPT']
  config.handlers.common.jira.allowed_update_users             = ENV['ALLOWED_UPDATE_USERS']

  config.handlers.common.mode.mode_token                       = ENV['MODE_TOKEN']
  config.handlers.common.mode.mode_password                    = ENV['MODE_PASSWORD']
  config.handlers.common.mode.mode_time_wait                   = ENV['MODE_TIME_WAIT']
  config.handlers.common.mode.labels                           = ENV['LABELS']
  config.handlers.common.mode.log_warning                      = ENV['LOG_WARNING']
  config.handlers.common.mode.email_username                   = ENV['EMAIL_USERNAME']
  config.handlers.common.mode.email_password                   = ENV['EMAIL_PASSWORD']
  config.handlers.common.mode.to_email                         = ENV['TO_EMAIL']
  config.handlers.common.mode.cc_email                         = ENV['CC_EMAIL']
  config.handlers.common.mode.od_prod_occurence                = ENV['OD_PROD_OCCURENCE_THRESHOLD']
  config.handlers.common.mode.od_dev_occurence                 = ENV['OD_DEV_OCCURENCE_THRESHOLD']
  config.handlers.common.mode.cozmo_prod_occurence             = ENV['COZMO_PROD_OCCURENCE_THRESHOLD']
  config.handlers.common.mode.cozmo_dev_occurence              = ENV['COZMO_DEV_OCCURENCE_THRESHOLD']
  config.handlers.common.mode.od_prod_url                      = ENV['OD_PROD_MODE_URL']
  config.handlers.common.mode.od_dev_url                       = ENV['OD_DEV_MODE_URL']
  config.handlers.common.mode.cozmo_prod_url                   = ENV['COZMO_PROD_MODE_URL']
  config.handlers.common.mode.cozmo_dev_url                    = ENV['COZMO_DEV_MODE_URL']
  config.handlers.common.mode.od_dev_url_error                 = ENV['OD_DEV_MODE_URL_SPECIFIC_ERROR']
  config.handlers.common.mode.cozmo_dev_url_error              = ENV['COZMO_DEV_MODE_URL_SPECIFIC_ERROR']
  config.handlers.common.mode.mode_report_timeout              = ENV['MODE_REPORT_TIMEOUT']
  config.handlers.common.mode.dev_das_version_url              = ENV['DEV_DAS_VERSION_MODE_URL']
  config.handlers.common.mode.prod_das_version_url             = ENV['PROD_DAS_VERSION_MODE_URL']
  config.handlers.common.mode.beta_das_version_url             = ENV['BETA_DAS_VERSION_MODE_URL']
  config.handlers.common.mode.das_table_name                   = ENV['DAS_TABLE_NAME']
  config.handlers.common.mode.query_timeout                    = ENV['QUERY_TIMEOUT']
  config.handlers.common.mode.vector_events                    = ENV['VECTOR_EVENTS']

  config.handlers.common.git.git_token                         = ENV['GIT_TOKEN']
  config.handlers.common.git.git_api_uri_vector                = ENV['GIT_API_URI_VECTOR']

end
