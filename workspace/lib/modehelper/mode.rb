require "rest-client"
module ModeHelper
  # Issues
  module Mode
    RUNTIME_EXCEPTION_PREFIX_MESSAGE = "Runtime exception"
    WILDCARD_ENCODE                  = "%25"
    # Define functions
    # Get the data from URL
    def get_data_from_mode(url)
      c = Curl::Easy.new(url)
      c.ssl_verify_peer = false
      c.http_auth_types = :basic
      c.username = config.mode.mode_token
      c.password = config.mode.mode_password
      c.perform
      data = c.body_str
      return data
    end
    def get_data_from_mode_result_url(result_url)
      data = ""
      begin
        data = RestClient::Request.execute method: :get, url: result_url, user: config.mode.mode_token, password: config.mode.mode_password, verify_ssl: false 
      rescue => ex
        data = "run has not completed"
      end
      return data.to_s
    end

    # Get correct URL and add 'api' text
    def convert_a_url_to_api_url(url)
      return url[url.index('http'), url.rindex('">') - url.index('http')].sub('anki','api/anki')
    end

    # Convert Data to JSON format
    def convert_data_to_json_format(savedata)
      result = []
      rows = savedata.split(/\r?\n/)
      keys = rows[0].split(',')
      rows.shift
      rows.each do |d|
          values = d.split(',')
          result << Hash[keys.zip(values)]
      end
      return result
    end

    def aggregate_event(json_data)
      json_data.each do |key|
      # Handle the event contain ',' characters
        if(key['app']==nil || key['app']=='')
          key['app'] = 'UNKNOWN'
        end
        key['app'] += " (#{key['occurrences']})"
      end
      i = 0
      n = json_data.length
      while i< n
        j = i+1
        while j < n
          if (json_data[i]['event']==json_data[j]['event'])
            json_data[i]['app']+="\n" + json_data[j]['app']
            occurrences = json_data[i]['occurrences'].to_i + json_data[j]['occurrences'].to_i
            json_data[i]['occurrences']= occurrences
            json_data.delete_at(j)
          else
            j+=1
          end
          n= json_data.length
        end
        i+=1
      end

      # Sort data by occurrences and level values
      json_data = json_data.sort_by { |h| [h['level'], -h['occurrences'].to_i] }
      return json_data
    end

    def get_data_from_mode_by_time_period(mode_url)

      # Get the latest runs URL from Latest Error And Warning URL by using paremeter run=nows
      latestURL = get_data_from_mode(mode_url)
      # The data should be returned: "<html><body>You are being 
      #<a href="https://modeanalytics.com/anki/reports/30dd44e348c0/runs/
      #c8ffb7c13a09">redirected</a>.</body></html>"

      # Convert the URL to API URL
      latestURL = convert_a_url_to_api_url(latestURL)
      # the API URL should be converted: "https://
      #modeanalytics.com/api/anki/reports/30dd44e348c0/runs/c8ffb7c13a09"

      modeURL = latestURL[0, latestURL.index('/api')]

      # Get JSON data from API URL
      data = get_data_from_mode(latestURL)
      # The JSON data should be returned: 
      #{"token":"c8ffb7c13a09","state":"enqueued"
      #,"parameters":{"period":"day"},"data_source_id":1851,
      #"created_at":"2016-02-05T04:19:47.735Z",
      #"updated_at":"2016-02-05T04:19:47.774Z","completed_at":null,
      #"_links":{"self":{"href":"/api/anki/reports/30dd44e348c0/runs
      #/c8ffb7c13a09?embed[result]=1"},"account":{"href":"/api/anki"},
      #"executed_by":{"href":"/api/vuongvo"},"share":
      #{"href":"/anki/reports/30dd44e348c0/runs/c8ffb7c13a09"},
      #"report":{"href":"/api/anki/reports/30dd44e348c0"},
      #"clone":{"href":"/anki/reports/30dd44e348c0/runs/c8ffb7c13a09/clone"},
      #"query_runs":{"href":"/api/anki/reports/30dd44e348c0/runs/
      #c8ffb7c13a09/query_runs"},"pdf_export":{"href":"/api/anki/reports/
      #30dd44e348c0/exports/runs/c8ffb7c13a09/pdf"}},"_forms":{"edit":
      #{"method":"patch","action":"/api/anki/reports/30dd44e348c0/runs/
      #c8ffb7c13a09","input":{"report_run":{"dataset":{"count":{"type":"text"},
      #"content":{"type":"file"},"columns":{"type":"text"}},"error":{"message":
      #{"type":"text"},"detail":{"type":"text"}}}}},"cancel":{"method":"put",
      #"action":"/api/anki/reports/30dd44e348c0/runs/c8ffb7c13a09/cancel"}}}

      # Parse data to JSON format
      dataJSON = JSON.parse(data)

      # Get last_run_url form JSON
      lastRunURL = dataJSON['_links']['self']['href']
      lastRunURL = lastRunURL[0, lastRunURL.rindex('?')]

      # Download the content csv file base on the last run URL
      resultsURL = "#{modeURL}#{lastRunURL}/results/content.csv"

      # Handle to wait for Data is loaded successfully
      count = 0
      mode_time_wait = config.mode.mode_time_wait.to_i

      while count < mode_time_wait # Wait for 'mode_time_wait' time
        data = get_data_from_mode_result_url(resultsURL)
        # If data isn't loaded successfully, a message will be returned: 
        #"{"id":"not_found","message":"run has not completed","_links":
        #{"help":{"href":"http://help.modeanalytics.com"}}}"
          if !(data.include? 'run has not completed')
          break
        else
          sleep 1
          count += 1
        end
      end

      if count == mode_time_wait
        # Get data unsuccesful, return false
        return false
      end

      jsonData = []
      if data.to_s != ""
        begin
          jsonData = convert_data_to_json_format(data.to_s)
        rescue => ex
          jsonData = "#{RUNTIME_EXCEPTION_PREFIX_MESSAGE} : #{ex.message}"
        end
      end
      return jsonData
    end

    #Get mode link dev specific error to query based on project
    def get_mode_link_dev_specific_error(project)
      return_link=''
      if project == 'overdrive'
          return_link = config.mode.od_dev_url_error
      elsif project == 'cozmo'
          return_link =  config.mode.cozmo_dev_url_error
      end
    end
    #Get real value of project
    def get_project_message_table(project)
      message_table=''
      if project == 'overdrive'
        message_table = 'odmessage'
      elsif project == 'cozmo'
        message_table = 'cozmomessage'
      end

      return message_table
    end

    def get_all_errors_event(project)
      data = []
      #Get link mode dev specific error to query base on 'project'
      link_mode = get_mode_link_dev_specific_error(project)
      #Get real value of project
      real_project = get_project_message_table(project)
      #Create link_mode query all event
      link_mode = "#{link_mode}?param_event_name=#{WILDCARD_ENCODE}&&param_product=#{real_project}"
      data = get_data_from_mode_by_time_period(link_mode)

      return data
    end

    # Check event still happend on mode or not
    def event_still_occurs(event, jsonData)
      event_occurrence = false
      events = jsonData.map.select { |item| item["event"] == event }
      if events.size() > 0
        event_occurrence = true
      end

      return event_occurrence
    end

    #Get occurence base on platform and is_prod
    def get_mode_url(platform, is_prod)
      mode_url = ""
      if platform == 'overdrive'
        if is_prod
          mode_url = config.mode.od_prod_url
        else
          mode_url = config.mode.od_dev_url          
        end
      elsif platform == 'cozmo'
        if is_prod
          mode_url = config.mode.cozmo_prod_url
        else
          mode_url = config.mode.cozmo_dev_url          
        end        
      end
      return mode_url
    end

    #Get occurence base on platform and is_prod
    def get_occurence(platform, is_prod)
      occurence = ""
      if platform == 'overdrive'
        if is_prod
          occurence = config.mode.od_prod_occurence
        else
          occurence = config.mode.od_dev_occurence          
        end
      elsif platform == 'cozmo'
        if is_prod
          occurence = config.mode.cozmo_prod_occurence
        else
          occurence = config.mode.cozmo_dev_occurence          
        end        
      end
      return occurence
    end

    def get_database_name(mode_url)
      db_name = ""
      if mode_url == config.mode.dev_das_version_url
        db_name = "Redshift Dev"
      elsif mode_url == config.mode.prod_das_version_url
        db_name = "Redshift Prod"
      else 
        db_name = "Redshift Beta"
      end
      return db_name
    end

    def get_valid_project_name(project_name)
      projects = eval(config.jira.projects)
      real_project_name = projects[project_name.downcase]
      return real_project_name
    end

    def is_event_supported(event_name)
      is_supported = false
      vector_events = eval(config.mode.vector_events)
      is_supported = vector_events.key?(event_name)
      return is_supported
    end

    def get_mode_link_by_event(event_name)
      mode_link = ""
      vector_events = eval(config.mode.vector_events)
      mode_link = vector_events[event_name]
      return mode_link
    end

    def convert_hashes_to_readable_string(hashes)
      readable_string = ""
      for hash_item in hashes do
        item_data = hash_item.map { |k,v| "*#{k}* : #{v}" }
        readable_string += item_data.join(', ') + "\n"
      end
      return readable_string
    end
  end
end
