module ConfluenceHelper
  module ConfluenceParser

    def get_release_schedule(build)
      schedule = Array.new
      release_schedule = get_current_release_schedule()
      release_schedule.each do |schedule_item|
        build_name = information_schedule_item(schedule_item, ConfluenceConstant::BUILD)
        if build_name != nil
          if build_name.downcase.include? build.downcase
            schedule.push(schedule_item)
          end
        end
      end
      return schedule
    end

    def format_schedule_item(schedule_item)
      return "#{information_schedule_item(schedule_item, ConfluenceConstant::BUILD)} "\
                  "#{ConfluenceConstant::BRANCH_DATE_NAME} " +
             "#{information_schedule_item(schedule_item, ConfluenceConstant::BRANCH_DATE)}, "\
                  "#{ConfluenceConstant::SUBMIT_DATE_NAME} " +
             "#{information_schedule_item(schedule_item, ConfluenceConstant::SUBMIT_DATE)}, "\
                  "#{ConfluenceConstant::RELEASE_DATE_NAME} " +
             "#{information_schedule_item(schedule_item, ConfluenceConstant::RELEASE_DATE)}"
    end

    def format_schedule(build, schedule)
      information_schedule = t('release_schedule.result', build: build)
      schedule.each do |schedule_item|
        information_schedule = information_schedule+"\n"+format_schedule_item(schedule_item)
      end
      return information_schedule
    end

    def get_current_release_schedule()
      schedule = nil
      page_id = config.jira.release_page_id
      url = "#{config.jira.site}/wiki/rest/api/content/#{page_id}?expand=body.storage"
      result = client.get(url)
      jsonObj = JSON.parse(result.body)
      jsonObjValue = convert_html_to_json(jsonObj['body']['storage']['value'])
      schedule = jsonObjValue['html']['table']['tbody']['tr']
      #Remove header name at first row
      schedule = schedule[1..-1]
      return schedule
    end

    def convert_html_to_json(html_content)
      full_html = "<html>#{html_content}</html>"
      js = Hash.from_xml(full_html).to_json
      return JSON.parse(js)
    end

  end
end
