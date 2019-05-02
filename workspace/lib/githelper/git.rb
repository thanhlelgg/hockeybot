module GitHelper
  module Git

    OTA_CODE_TABLE                   = "OTA / Recovery Error Codes"
    ROBOT_SCREEN_CODE_TABLE          = "Robot Screen error codes"
    PLAYPEN_FAILURE_CODE_TABLE       = "Playpen Failure Codes"
    START_ENUM_OF_FAULT_CODES        = "enum : uint16_t {"
    END_ENUM_OF_FAULT_CODES          = "COUNT = 1000"
    START_FACTORY_TEST_RESULT_CODE   = "enum uint_8 FactoryTestResultCode {"
    END_FACTORY_TEST_RESULT_CODE     = "NO MORE SPACE"
    OTA_RECOVERY_ERROR_CODES_PATH    = "contents/platform/update-engine/error-codes.md"
    ROBOT_SCREEN_ERROR_CODES_PATH    = "contents/robot/include/anki/cozmo/shared/factory/faultCodes.h"
    PLAYPEN_FAILURE_ERROR_CODES_PATH = "contents/clad/src/clad/types/factoryTestTypes.clad"

    def get_git_file_content(url, token)
      c = Curl::Easy.new(url)
      c.headers["User-Agent"]    = "github"
      c.headers["Authorization"] = "token #{token}"
      c.headers["Accept"]        = "application/vnd.github.v3.raw"
      c.perform
      return c.body_str
    end

    def define_error_reason_follows_code_table(reason)
      reason_array     = reason.split("|")
      current_reason   = reason_array[0]
      table_error_name = reason_array[1]
      return "#{table_error_name}\nreason: #{current_reason}"
    end

    def format_error_reason(reason, code_table)
      return "#{reason}|#{code_table}"
    end

    def get_error_reason(reasons)
      reason_array = []
      if !reasons.kind_of?(Array)
        reasons = ["#{reasons}"]
      end
      reasons.each do |reason|
        reason_array.append(define_error_reason_follows_code_table(reason))
      end
      return reason_array
    end

    def detect_reason_error_by_code(code)
      error_code_dict = get_error_code_dict()
      error_reason = ""
      if error_code_dict.key?(code)
        error_reason = get_error_reason(error_code_dict[code])
      end
      return error_reason
    end

    def get_code_content(code_content, start_code, end_code)
      return code_content.match(/#{start_code}(.*)#{end_code}/m)[1]
    end

    def get_ota_recovery_error_code_dict()
      url = "#{config.git.git_api_uri_vector}/#{OTA_RECOVERY_ERROR_CODES_PATH}"
      token = config.git.git_token
      code_dict = {}
      begin
        content = get_git_file_content(url, token)
        # format of table content likes that: |   1  | Switchboard: unknown status           |#
        content.each_line do |line|
          if line.start_with?("|")
            temp = line.split("|")
            error_code = temp[1].gsub(" ","")
            error_value = temp[2].lstrip.chop
            error_reason = format_error_reason(error_value, OTA_CODE_TABLE)
            code_dict[error_code] = error_reason
          end
        end
      rescue Exception => ex
        log.info "get_ota_recovery_error_code_dict has exception: #{ex}"
      end
      return code_dict
    end

    def get_robot_screen_error_code_dict()
      url = "#{config.git.git_api_uri_vector}/#{ROBOT_SCREEN_ERROR_CODES_PATH}"
      token = config.git.git_token
      code_dict = {}
      begin
        content = get_git_file_content(url, token)
        value = get_code_content(content, START_ENUM_OF_FAULT_CODES, END_ENUM_OF_FAULT_CODES)
        value.each_line do |line|
          next if line.strip().chomp.empty?
          next if line.strip().start_with?("//")
          error_code = line.match(/=(.*),/)[1].strip()
          error_value = line.match(/(.*)=/)[1].strip()
          error_reason = format_error_reason(error_value, ROBOT_SCREEN_CODE_TABLE)
          code_dict[error_code] = error_reason
        end
      rescue Exception => ex
        log.info "get_robot_screen_error_code_dict has exception: #{ex}"
      end
      return code_dict
    end

    def get_playpen_failure_code_dict()
      url = "#{config.git.git_api_uri_vector}/#{PLAYPEN_FAILURE_ERROR_CODES_PATH}"
      token = config.git.git_token
      code_dict = {}
      begin
        content = get_git_file_content(url, token)
        value = get_code_content(content, START_FACTORY_TEST_RESULT_CODE, END_FACTORY_TEST_RESULT_CODE)
        error_code  = 0
        value.each_line do |line|
          next if line.strip().chomp.empty?
          next if line.strip().start_with?("//")
          error_value = line.match(/(.*),/)[1].strip().gsub(" = 0", "")
          error_reason = format_error_reason(error_value, PLAYPEN_FAILURE_CODE_TABLE)
          code_dict[error_code.to_s] = error_reason
          error_code += 1
        end
      rescue Exception => ex
        log.info "get_playpen_failure_code_dict has exception: #{ex}"
      end
      return code_dict
    end

    def merge_multi_dict(dict1, dict2)
      dict = dict1.merge(dict2){|k,v1,v2|[v1,v2]}
      return dict
    end

    def get_error_code_dict()
      ota_code_dict = get_ota_recovery_error_code_dict()
      robot_screen_code_dict = get_robot_screen_error_code_dict()
      playpen_failure_code_dict = get_playpen_failure_code_dict()
      error_code_dict = merge_multi_dict(ota_code_dict, robot_screen_code_dict)
      error_code_dict = merge_multi_dict(error_code_dict, playpen_failure_code_dict)
      return error_code_dict
    end

  end
end
