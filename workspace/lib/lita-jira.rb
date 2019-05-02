require "lita"

Lita.load_locales Dir[File.expand_path(
  File.join("..", "..", "locales", "*.yml"), __FILE__
)]

gem 'jira-ruby'
require 'jira'
require 'mail'
require 'csv'
require 'rubygems'
require 'pp'
require 'modehelper/mode'
require 'modehelper/email'
require 'jirahelper/issue'
require 'jirahelper/misc'
require 'jirahelper/jira'
require 'jirahelper/git'
require 'confluencehelper/confluence'
require 'confluencehelper/confluenceparser'
require 'confluencehelper/confluenceconstant'
require 'githelper/git'
require 'lita/handlers/common'
require 'lita/handlers/mode'
require 'lita/handlers/jira'
require 'lita/handlers/confluence'
require 'lita/handlers/ez_office_inventory'
require 'lita/handlers/git'
require 'lita/adapters/slack'

Lita::Handlers::Jira.template_root File.expand_path(
  File.join("..", "..", "templates"),
 __FILE__
)
