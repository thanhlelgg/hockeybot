# lita-jira plugin
module Lita
  # Because we can.
  module Handlers
    # Main handler
    # rubocop:disable Metrics/ClassLength
    class Git < Handler
      namespace 'common'

      include ::GitHelper::Git

      CODE_PATTERN = /(?<code>[0-9]{1,5})/

      route(%r{.*vector_error_code\s#{CODE_PATTERN}}i,
        :get_vector_error_reason_by_code,
        command: false,
        help: {t('help.vector_error_code.syntax') => t('help.vector_error_code.desc')}
      )

      def get_vector_error_reason_by_code(response)
        code = response.match_data["code"]
        reason = detect_reason_error_by_code(code)
        return response.reply(t('vector_code.code_not_found')) if reason.empty?
        response.reply(reason)
      end

      # rubocop:enable Metrics/AbcSize
    end
    # rubocop:enable Metrics/ClassLength
    Lita.register_handler(Git)
  end
end
