
# lita-jira plugin
module Lita
  # Because we can.
  module Handlers
    # Main handler
    # rubocop:disable Metrics/ClassLength
    class Confluence < Handler
    # rubocop:enable Metrics/AbcSize
      namespace 'common'

      include ::ConfluenceHelper::Confluence
      include ::ConfluenceHelper::ConfluenceParser
      include ::JiraHelper::Misc


      route(%r{dates(.*)}i,
          :release_schedule ,
          command: true,
          help: {t('help.release_schedule.syntax') => t('help.release_schedule.desc')}
      )

      def release_schedule(response)
        result = ""
        info = response.matches[0][0].strip
        arguments = info.split(' ')
        argument_platform = ""
        argument_version = ""
        argument_detail = ""

        if arguments.length > 0
          argument_platform = arguments[0]
        end
        if arguments.length > 1
          argument_version = arguments[1]
          if argument_version.include? ','
            argument_version.gsub!(',','')
          end
        end
        if arguments.length > 2
          argument_detail = arguments[2..-1].join(" ")
        end

        projects = eval(config.jira.projects)
        platform = projects[argument_platform.downcase]
        build = (argument_version == "") ? platform : "#{platform} #{argument_version}"
        if argument_detail == ""
          schedule = get_release_schedule(build)
          result = format_schedule(build, schedule)
        else
          result = update_release_schedule(build, argument_detail)
        end
        response.reply(result)
      end
    end
    # rubocop:enable Metrics/ClassLength
    Lita.register_handler(Confluence)
  end
end
