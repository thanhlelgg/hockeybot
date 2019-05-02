require 'spec_helper'

describe Lita::Handlers::Jira, lita_handler: true do
  before do
    registry.config.handlers.common.mode.query_timeout = "30"
    registry.config.handlers.common.jira.package_apps = '{"OD": "com.anki.overdrive", "COZMO": "com.anki.cozmo"}'
    registry.config.handlers.common.jira.url_googleplay_api = "https://play.google.com/store/apps/details?hl=en&id="
    registry.config.handlers.common.jira.url_applestore_api = "http://itunes.apple.com/lookup?bundleId="
    registry.config.handlers.common.jira.projects = "{'OverDrive'=>'OD','overdrive'=>'OD','cozmo'=>'COZMO','Cozmo'=>'COZMO',
                                                      'CozmoOne'=>'COZMO','VICTOR'=>'VIC','Victor'=>'VIC','Vic'=>'VIC',
                                                      'victor'=>'VIC','vic'=>'VIC',}"
    registry.config.handlers.common.mode.das_table_name = '{"OD": "das.odmessage", "COZMO": "das.cozmomessage"}'
    registry.config.handlers.common.mode.dev_das_version_url = "https://modeanalytics.com/anki/reports/"\
                                                               "deb8d35a9ac1?param_period=PERIOD&run=now"
    registry.config.handlers.common.mode.prod_das_version_url = "https://modeanalytics.com/anki/reports/"\
                                                                "deb8d35a9ac1?param_period=PERIOD&run=now"
    registry.config.handlers.common.mode.beta_das_version_url = "https://modeanalytics.com/anki/reports/"\
                                                                "deb8d35a9ac1?param_period=PERIOD&run=now"
    registry.config.handlers.common.mode.mode_time_wait = "5"
    registry.config.handlers.common.jira.max_results = '1000'
    registry.config.handlers.common.jira.crashes_filter = "{'cozmo-crashes'=>20101,'od-crashes'=>30201," \
                                                          "'cozmo-last-24'=>30203,'od-last-24'=>30202}"
    registry.register_handler(Lita::Handlers::Jira)
    registry.config.handlers.common.jira.site = 'https://jira.local'
    registry.config.handlers.common.jira.max_results = "1000"
    registry.config.handlers.common.jira.hockeyapp_master_app_ids = '{"XXX": "5caab2ce2b3df230f30ad8428e0329d3",'\
                                                                    '"XYZ": "3e78b35bae854fa8b3137db388bed136",'\
                                                                    '"XYZ_IOS": "714e67f2ff5248469ee4d8419d0dfd74",'\
                                                                    '"XXX_IOS": "99304009eb0a0fe6a34939617e4daf4b"}'
    registry.config.handlers.common.jira.hockeyapp_url = "https://fake.hockeyapp.net/api/2/apps"
    registry.config.handlers.common.jira.hockeyapp_token = "b545e9783066491"
    registry.config.handlers.common.jira.project_close_transitions = "{'OD'=>{'In Progress'=>['1','2']}}"
    registry.config.handlers.common.jira.allowed_update_users = 'U17B8V7CZ,U040HGVJJ'
    registry.config.handlers.common.jira.project_open_transitions = "{'OD'=>'101','COZMO'=>'341'}"
    registry.config.handlers.common.jira.context = ''
    registry.config.handlers.common.jira.teamcity_info = eval("{'XYZ'=>['XYZ_Dev_PullRequestsIOS',
                                                              'XYZ_Dev_PullRequestAndroid','XYZ']}")
    registry.config.handlers.common.jira.teamcity_uri = 'https://teamcity_uri.com'
    registry.config.handlers.common.jira.str_excludes = "fault addr ,libmono.,Unknown.,BLECentralMultiplexer " \
                                                        "centralManager:didDiscoverPeripheral:advertisementData:RSSI," \
                                                        "storage/emulated/0/Android/data/,line ,OutOfMemoryError: Failed to allocate a "
    registry.config.handlers.common.jira.hockeyapp_url = "https://fake.hockeyapp.net/api/2/apps"
    registry.config.handlers.common.jira.hockeyapp_token = "b545e9783066491"
    registry.config.handlers.common.jira.components  = "crashes,errors,release checklist"

    registry.config.handlers.common.jira.git_uri_od = "git@github.com:/company/a.git"
    registry.config.handlers.common.jira.git_uri_cozmo = "git@github.com:/company/b.git"

    registry.config.handlers.common.jira.components = "crashes,errors,release checklist"
    registry.config.handlers.common.jira.vip_category_column = "{'name'=>'customfield_11404','value'=>{'KS'=>['101','001']}}"
    registry.config.handlers.common.mode.vector_events = "{'app'=>'https://modeanalytics.com/local/reports/app11111?run=now',"\
                                                          "'robot'=>'https://modeanalytics.com/local/reports/robot11111?run=now',"\
                                                          "'cloud'=>'https://modeanalytics.com/local/reports/cloud11111?run=now'}"

    registry.config.handlers.common.mode.od_prod_url = "https://fakemode.com/anki/reports/just4test?param_period"\
                                                       "=PERIOD&run=now"
    registry.config.handlers.common.mode.od_prod_occurence = "15000"
    registry.config.handlers.common.jira.vip_category_column = "{'name'=>'customfield_11404',"\
                                                               "'value'=>{'KS'=>['101','001']}}"

    redirect_html_android = '<div class="BgcNfc">Current Version</div><span class="htlgb"><div class="BgcNfc"><span class="htlgb">3.4.0</span>'
    redirect_html_ios = '{"results": [{"version":"3.4.0"}]}'
    stub_request(:get, /play.google.com/).to_return(:status => 200, :body => redirect_html_android)
    stub_request(:get, /itunes.apple.com/).to_return(:status => 200, :body => redirect_html_ios)
    $lita_variable = get_variables()
  end

  let(:saved_pullrequest_no_data) do
    result = double(body: '{"detail":[{"pullRequests":[]}]}')
    result
  end

  let(:saved_pullrequest_has_data) do
    result = double(body: '{"detail":[{"pullRequests":[{"id":"#123456","url":'\
                          '"https://github.com/123456"}]}]}')
    result
  end

  let(:transition_issue) do
    transition = double(expand: 'transitions',
                        transitions: [{'id' => '1',
                                       'name' => 'Close'},
                                      {'id' => '2',
                                       'name' => 'Open'}])
    allow(transition).to receive_message_chain('save') { true }
    transition
  end

  let(:invalid_transition_issue) do
    transition = double
    response = instance_double("Response", body: '{"errorMessages":["blah"]}', status: 400)
    expect(transition).to receive_message_chain('save').and_throw(JIRA::HTTPError.new(response))
    transition
  end

  let(:saved_issue) do
    result = double(summary: 'Some summary text',
                    assignee: double(displayName: 'A Person'),
                    priority: double(name: 'P0'),
                    status: double(name: 'In Progress'),
                    fixVersions: [{ 'name' => 'Sprint 2' }],
                    project: {"id" => "1", "key" => "XYZ", "name" => "XYZ"},
                    customfield_11404: {"self" => "https://jira.local/rest/api/2/customFieldOption/10518",
                                        "value" => "010", "id" => "10518"},
                    fields: {'customfield_11602' => '12'},
                    description: 'This is description of issue',
                    id: '111111',
                    key: 'XYZ-987',
                    watches: {'self' => 'https://site.atlassian.net/rest/api/2/issue/XYZ-987/watchers'})
    allow(result).to receive('save') { true }
    allow(result).to receive('save!') { true }
    allow(result).to receive('fetch') { true }
    result
  end

  let(:invalid_saved_issue) do
    result = double(fields: {'customfield_11604' => '12'},
                    key: 'XYZ-987')
    allow(result).to receive('save') { true }
    allow(result).to receive('save!') { true }
    allow(result).to receive('fetch') { true }
    result
  end

  let(:saved_filter) do
    result = double(id: 'id1',
                    name: 'crash-name1',
                    jql: 'project = XYZ')
    result
  end

  let(:saved_issue_with_fewer_details_affect_version) do
    result = double(fields: {"versions" => [{ 'name' => '1.0.0' },
                                            { 'name' => '1.0.1' },
                                            { 'name' => '1.0.2' }]})
    result
  end

  let(:saved_issue_with_fewer_details_not_affect_version) do
    result = double(fields: {"versions" => []})
    result
  end

  let(:saved_issue_with_fewer_details) do
    result = double(summary: 'Some summary text',
                    status: double(name: 'In Progress'),
                    fixVersions: [],
                    project: {"id" => "1", "key" => "XYZ", "name" => "XYZ"},
                    customfield_11404: {"self" => "https://jira.local/rest/api/2/customFieldOption/10518",
                                        "value" => "010", "id" => "10518"},
                    key: 'XYZ-987')
    allow(result).to receive('assignee').and_raise
    allow(result).to receive('priority').and_raise
    allow(result).to receive('save') { true }
    allow(result).to receive('fetch') { true }
    result
  end

  let(:saved_issue_with_valid_transition) do
    result = double(fields: {'status' => {'name' => 'In Progress'}},
                    key: 'XYZ-1')
    allow(result).to receive('save') { true }
    allow(result).to receive('save!') { true }
    allow(result).to receive('fetch') { true }
    allow(result).to receive_message_chain('transitions.build').and_return(transition_issue)
    allow(result).to receive_message_chain('comments.build.save!') { true }
    result
  end

  let(:saved_issue_with_invalid_transition) do
    result = double(fields: {'status' => {'name' => 'In Progress'}},
                    key: 'XYZ-1')
    allow(result).to receive('save') { true }
    allow(result).to receive('save!') { true }
    allow(result).to receive('fetch') { true }
    allow(result).to receive_message_chain('transitions.build').and_return(invalid_transition_issue)
    allow(result).to receive_message_chain('comments.build.save!') { true }
    result
  end

  let(:valid_search_results) do
    result = [double(summary: 'Some summary text',
                     assignee: double(displayName: 'A Person'),
                     priority: double(name: 'P0'),
                     status: double(name: 'In Progress'),
                     fixVersions: [{ 'name' => 'Sprint 2' }],
                     project: {"id" => "1", "key" => "XYZ", "name" => "XYZ"},
                     customfield_11404: {"self" => "https://jira.local/rest/api/2/customFieldOption/10518",
                                         "value" => "010", "id" => "10518"},
                     key: 'XYZ-987'),
              double(summary: 'Some summary text 2',
                     assignee: double(displayName: 'A Person 2'),
                     priority: double(name: 'P1'),
                     status: double(name: 'In Progress 2'),
                     fixVersions: [],
                     project: {"id" => "1", "key" => "XYZ", "name" => "XYZ"},
                     customfield_11404: {"self" => "https://jira.local/rest/api/2/customFieldOption/10518",
                                         "value" => "010", "id" => "10518"},
                     key: 'XYZ-988')]
    allow(result).to receive('fetch') { true }
    result
  end

  let(:searched_issue_with_valid_transition) do
    result = [saved_issue_with_valid_transition]
    allow(result).to receive('fetch') { true }
    result
  end

  let(:searched_issue_with_invalid_transition) do
    result = [saved_issue_with_invalid_transition]
    allow(result).to receive('fetch') { true }
    result
  end

  let(:saved_project) do
    double(key: 'XYZ',
           id: 1)
  end

  let(:valid_client) do
    issue = double
    max_result = registry.config.handlers.common.jira.max_results.to_i
    query_options_stop = {
      :fields => [],
      :start_at => max_result,
      :max_results => max_result
    }
    allow(issue).to receive_message_chain('Issue.find') { saved_issue }
    allow(issue).to receive_message_chain('Issue.find.comments.build.save!') { saved_issue }
    allow(issue).to receive_message_chain('Issue.build') { saved_issue }
    allow(issue).to receive_message_chain('Project.find') { saved_project }
    allow(issue).to receive_message_chain('Issue.jql') { valid_search_results }
    allow(issue).to receive_message_chain('Issue.jql').with(anything(), query_options_stop) { [] }
    issue
  end

  let(:filtered_no_issue) do
    issue = double
    allow(issue).to receive_message_chain('Filter.find') { saved_filter }
    allow(issue).to receive_message_chain('Issue.jql') { [] }
    allow(issue).to receive_message_chain('Project.find') { saved_project }
    allow(issue).to receive_message_chain('Issue.build') { saved_issue }
    allow(issue).to receive_message_chain('Issue.find') { saved_issue }
    issue
  end

  let(:filtered_has_issue) do
    issue = double
    max_result = registry.config.handlers.common.jira.max_results.to_i
    query_options_stop = {:fields => [],
                          :start_at => max_result,
                          :max_results => max_result}
    allow(issue).to receive_message_chain('Filter.find') { saved_filter }
    allow(issue).to receive_message_chain('Issue.jql') { valid_search_results }
    allow(issue).to receive_message_chain('Issue.jql').with(anything(), query_options_stop) { [] }
    issue
  end

  let(:invalid_client) do
    issue = double
    allow(issue).to receive_message_chain('Issue.find') { invalid_saved_issue }
    issue
  end

  let(:valid_client_with_valid_transition_issue) do
    issue = double
    max_result = registry.config.handlers.common.jira.max_results.to_i
    query_options_stop = {:fields => [],
                          :start_at => max_result,
                          :max_results => max_result}
    allow(issue).to receive_message_chain('Issue.jql') { searched_issue_with_valid_transition }
    allow(issue).to receive_message_chain('Issue.jql').with(anything(), query_options_stop) { [] }
    issue
  end

  let(:invalid_client_with_invalid_transition_issue) do
    issue = double
    max_result = registry.config.handlers.common.jira.max_results.to_i
    query_options_stop = {:fields => [],
                          :start_at => max_result,
                          :max_results => max_result}
    allow(issue).to receive_message_chain('Issue.jql') { searched_issue_with_invalid_transition }
    allow(issue).to receive_message_chain('Issue.jql').with(anything(), query_options_stop) { [] }
    issue
  end

  let(:client_with_fewer_details) do
    issue = double
    allow(issue).to receive_message_chain('Issue.find') { saved_issue_with_fewer_details }
    issue
  end

  let(:failed_find_issue) do
    response = instance_double("Response", body: '{"errorMessages":["error"]}', status: 400)
    r = double
    expect(r).to receive_message_chain('Issue.find').and_throw(JIRA::HTTPError.new(response))
    r
  end

  let(:failed_find_issues) do
    response = instance_double("Response", body: '{"errorMessages":["blah"]}', status: 400)
    r = double
    expect(r).to receive_message_chain('Issue.jql').and_raise(JIRA::HTTPError.new(response))
    r
  end

  let(:failed_find_project) do
    response = instance_double("Response", body: '{"errorMessages":["error"]}', status: 400)
    r = double
    expect(r).to receive_message_chain('Project.find').and_throw(JIRA::HTTPError.new(response))
    r
  end

  let(:empty_search_result) do
    r = double
    allow(r).to receive_message_chain('Issue.jql') { [] }
    r
  end

  let(:failed_issue_build) do
    response = instance_double("Response", body: '{"errorMessages":["error"]}', status: 400)
    r = double
    allow(r).to receive_message_chain('Project.find') { saved_project }
    allow(r).to receive_message_chain('Issue.jql') { [] }
    expect(r).to receive_message_chain('Issue.build').and_raise(JIRA::HTTPError.new(response))
    r
  end

  let(:saved_task) do
    project = saved_project
    result = double(fields: {  project: { id: "#{project.id}" },
                               issuetype: { id: '7' },
                               assignee: { name: "chapados" },
                               summary: "#{project.key} 1.7.0 cut-branch",
                               components: [{ name: "release checklist" }],
                               customfield_11500: [{ name: "#{project.key} 1.7.0" }],
                               description: "Branch off Master to update the Release Candidate branch."
                            },
                    key: "#{project.key}-987")
    allow(result).to receive('save') { true }
    allow(result).to receive('fetch') { true }
    result
  end

  let(:valid_client_create_task) do
    issue = double
    allow(issue).to receive_message_chain('Project.find') { saved_project }
    allow(issue).to receive_message_chain('Issue.build') { saved_task }
    issue
  end
    
  let(:failed_save_issue) do
    response = instance_double("Response", body: '{"errorMessages":["error"]}', status: 400)
    r = double
    allow(r).to receive_message_chain('Project.find') { true }
    allow(r).to receive_message_chain('Issue.build') { true }
    allow(r).to receive_message_chain('Issue.fetch').and_throw(JIRA::HTTPError.new(response))
    r
  end

  describe '#productversion' do

    it 'production_version is updated after call check_and_update_prod_app_version if 
        production_version is nil' do
      subject.check_and_update_prod_app_version()
      expect(registry.config.handlers.common.jira.production_version .eql? nil).to be false
    end

    it 'production_version is NOT updated after call check_and_update_prod_app_version if 
        days_since_last_check < config.jira.production_version_update_freq_days' do
      registry.config.handlers.common.jira.production_version = "default"
      days_since_last_check_dummy = registry.config.handlers.common.jira.production_version_update_freq_days - 1
      registry.config.handlers.common.jira.production_version_last_checked = 
                                                          (Time.now - days_since_last_check_dummy.days).to_i
      subject.check_and_update_prod_app_version()
      expect(registry.config.handlers.common.jira.production_version .eql? "default").to be true
    end

    it 'production_version is updated after call check_and_update_prod_app_version if 
        days_since_last_check >= config.jira.production_version_update_freq_days' do
      registry.config.handlers.common.jira.production_version = "default"
      days_since_last_check_dummy = registry.config.handlers.common.jira.production_version_update_freq_days + 1
      registry.config.handlers.common.jira.production_version_last_checked = 
                                                          (Time.now - days_since_last_check_dummy.days).to_i
      subject.check_and_update_prod_app_version()
      expect(registry.config.handlers.common.jira.production_version .eql? "default").to be false
    end

    it 'production_version is updated after call update_prod_affects_versions' do
      registry.config.handlers.common.jira.production_version = "default"
      send_command('update_prod_affects_versions')
      expect(replies.last .eql? 'App versions have been updated, and they are: default').to be false
    end
  end

  describe '#cleanup_ks_issues' do

    it 'replies "No issues need to be cleaned up." if there is no issue found' do
      grab_request(empty_search_result)
      send_command('cleanup_ks_issues XYZ')
      expect(replies).to eq(['No issues need to be cleaned up.'])
    end

    it 'replies KS issues were closed successfully' do
      grab_request(valid_client_with_valid_transition_issue)
      send_command('cleanup_ks_issues OverDrive')
      expect(replies.first).to eq("The following 1 KS issues were closed successfully:\n [\"XYZ-1\"]")
    end

    it 'replies error message if closing issue occurs error' do
      grab_request(invalid_client_with_invalid_transition_issue)
      send_command('cleanup_ks_issues overdrive')
      expect(replies.last).to eq("An error occurred when trying to close XYZ-1: uncaught throw "\
      "#<JIRA::HTTPError: JIRA::HTTPError>\n")
    end

  end

  describe '#jira_query' do

    it 'The reply message is "No input data in CRASH_FILTER env!" if crashes_filter is nil' do
      registry.config.handlers.common.jira.crashes_filter = ""
      send_command('jiraquery cozmo-crashes')
      expect(replies.last).to eq("No input data in CRASH_FILTER env!")
    end

    it 'The reply message is invalid filter if crash name do not match filter' do
      send_command('jiraquery test')
      crashes_filter = eval(registry.config.handlers.common.jira.crashes_filter)
      expect(replies.last).to eq("Invalid filter! The crash filter should be #{crashes_filter.keys.join(", ")}")
    end

    it 'The reply message show the list of ticket found in filter' do
      grab_request(filtered_has_issue)
      expected_result = "jiralist [XYZ-987 XYZ-988 ]"
      send_command('jiraquery cozmo-crashes')
      expect(replies.last).to eq(expected_result)
    end

    it 'Check jql no issue found' do
      grab_request(filtered_no_issue)
      send_command('jiraquery cozmo-crashes')
      expect(replies.last).to eq("No issues were found!")
    end
  end

  describe '#details_pr' do

    it 'displays error.request message in last reply if issue is invalid' do
      grab_request(failed_find_issue)
      send_command('jirapr XYZ-987')
      expect(replies.last).to eq('Error fetching JIRA issue')
    end

    it 'displays git.no_pr message in last reply if issue is valid but there is no associated pull requests' do
      grab_request(valid_client)
      allow(valid_client).to receive(:get).and_return(saved_pullrequest_no_data)
      send_command('jirapr XYZ-987')
      expect(replies.last).to eq("<#{registry.config.handlers.common.jira.site}/browse/XYZ-987|XYZ-987>" \
                                 " Some summary text" \
                                 "\n*Status:* In Progress, *Pull Requests:* \n\n")
    end

    it 'shows detail of all pull requests in last reply if issue is valid and there are associated' \
       ' pull requests with issue' do
      grab_request(valid_client)
      allow(valid_client).to receive(:get).and_return(saved_pullrequest_has_data)
      send_command('jirapr XYZ-987')
      expect(replies.last).to eq("<#{registry.config.handlers.common.jira.site}/browse/XYZ-987|XYZ-987>" \
                                 " Some summary text\n*Status:* In Progress, *Pull Requests:* \n"\
                                 "<https://github.com/123456|#123456>" \
                                 "  <https://teamcity_uri.com/viewType.html?buildTypeId=" \
                                 "XYZ_Dev_PullRequestsIOS&branch_XYZ_Dev=123456%2Fhead&tab=buildTypeStatus" \
                                 "Div|iOS>  <https://teamcity_uri.com/viewType.html?buildTypeId=XYZ_Dev_" \
                                 "PullRequestAndroid&branch_XYZ_Dev=123456%2Fhead&tab=buildTypeStatusDiv|Android> \n\n")
    end
  end

  describe '#details_full' do

    it 'reply is error.request message if issue does not exist' do
      grab_request(failed_find_issue)
      send_command('jirafull XYZ-1')
      expect(replies.last).to eq('Error fetching JIRA issue')
    end

    it 'reply shows full issue detail if issue exists' do
      grab_request(valid_client)
      send_command('jirafull XYZ-987')
      expect(replies.last).to eq("<https://jira.local/browse/XYZ-987|XYZ-987> Some summary text\n*Status:* In Progress," \
                                 " *Assigned To:* A Person\n*Fix Version:* Sprint 2\n*VIP Category:* 010, *Priority:* P0")
    end
  end
  
  describe '#details_list_full' do

    it 'reply is error.request message if issue does not exist' do
      grab_request(failed_find_issue)
      send_command('jiralistfull [XYZ-1]')
      expect(replies).to eq(['Error fetching JIRA issue'])
    end

    it 'reply shows list of full issue detail if all issues exist' do
      grab_request(valid_client)
      send_command('jiralistfull [XYZ-987]')
      expect(replies).to eq(["<https://jira.local/browse/XYZ-987|XYZ-987> Some summary text\n*Status:* In Progress," \
                             " *Assigned To:* A Person\n*Fix Version:* Sprint 2\n*VIP Category:* 010, *Priority:* P0"])
    end
  end
  
  describe '#details_list' do

    it 'reply is error.request message if issue does not exist' do
      grab_request(failed_find_issue)
      send_command('jiralist [XYZ-1 XYZ-2]')
      expect(replies).to eq(['Error fetching JIRA issue'])
    end

    it 'reply shows list of issue detail if issues exist' do
      grab_request(valid_client)
      send_command('jiralist [XYZ-987]')
      expect(replies).to eq(["<https://jira.local/browse/XYZ-987|XYZ-987> Some summary text"])
    end
  end

  describe '#details' do

    it 'reply is error.request message if issue does not exist' do
      grab_request(failed_find_issue)
      send_command('jira XYZ-1009')
      expect(replies.last).to eq('Error fetching JIRA issue')
    end

    it 'reply shows issue detail if issue exists' do
      grab_request(valid_client)
      send_command('jira XYZ-987')
      expect(replies.last).to eq('<https://jira.local/browse/XYZ-987|XYZ-987> Some summary text')
    end
  end

  describe '#list_prod_affects_versions' do

    it 'config.jira.production_version updates when config.jira.production_version=nil' do
      send_command('list_prod_affects_versions')
      expect(registry.config.handlers.common.jira.production_version .eql? nil).to be false
    end

    it 'config.jira.production_version remains unchanged when config.jira.production_version!=nil' do
      registry.config.handlers.common.jira.production_version = "default"
      send_command('list_prod_affects_versions')
      expect(registry.config.handlers.common.jira.production_version).to eq("default")
    end
  end

  describe '#list_filter_configs' do

    it 'reply shows list of all crash filters' do
      send_command('list_filter_configs')
      expect(replies.size).to eq(4)
      expect(replies[0..3]).to eq([
                                    "jira filter 20101 = `jiraquery cozmo-crashes`",
                                    "jira filter 30201 = `jiraquery od-crashes`",
                                    "jira filter 30203 = `jiraquery cozmo-last-24`",
                                    "jira filter 30202 = `jiraquery od-last-24`"
                                  ])
    end
  end

  describe '#get_project_from_issue' do

    it 'entire input is returned after call get_project_from_issue if
        issue does not contains dash' do
      issue = 'BI1009'
      project_name = subject.get_project_from_issue issue
      expect(project_name).to eq(issue)
    end

    it 'JIRA project acronym is returned if Jira issue contains dash' do
      issue = 'BI-1009'
      project_name = subject.get_project_from_issue issue
      expect(project_name).to eq("BI")
    end
  end

  describe '#create_commit_list' do

    it 'commit_list updates when we call create_commit_list' do
      commit_list = subject.create_commit_list ["123","789","456"]
      expect(commit_list).to eq("456\n789\n123\n")
    end
  end

  describe '#release_list_all' do
    it 'shows list of issue summaries if jql has issues returned' do
      expected_reply = "<https://jira.local/browse/XYZ-987|XYZ-987>: In Progress\n"\
                       "<https://jira.local/browse/XYZ-988|XYZ-988>: In Progress 2\n"
      grab_request(valid_client)
      send_command('jirarelease XYZ ABC')
      expect(replies.last).to eq(expected_reply)
    end

    it 'shows error message if jql returns an exception' do
      grab_request(failed_find_issues)
      send_command('jirarelease XYZ ABC')
      expect(replies.last).to eq("Error fetching JIRA issue")
    end

    it 'shows empty message if jql has no issues returned' do
      grab_request(empty_search_result)
      send_command('jirarelease XYZ ABC')
      expect(replies.last).to eq("")
    end
  end

  describe '#does_attachment_exist' do
    it 'result returns false if attachment exists' do
      attachment_json = '{"fields":{"attachment":[{"filename":"1953.jpg"},{"filename":"1954.jpg"}]}}'
      issue_has_attachment = "XYZ-17067"
      stub_request(:get, /fields=attachment/).to_return(:status => 200, :body => attachment_json)
      result = subject.does_attachment_exist(issue_has_attachment)
      expect(result).to eq(false)
    end

    it 'result returns true if attachment does not exist' do
      attachment_json = '"fields":{"attachment":[]}'
      issue_no_attachment = "XYZ-5678"
      stub_request(:get, /fields=attachment/).to_return(:status => 200, :body => attachment_json)
      result = subject.does_attachment_exist(issue_no_attachment)
      expect(result).to eq(true)
    end
  end

  describe '#cherry_pick_commit' do
    invalid_branch = "invalid-branch"
    invalid_commit_id = "invalid-commit-id"
    valid_branch = "valid-branch"
    valid_commit_id = "valid-commit-id"

    before do
      allow_any_instance_of(JiraHelper::Git).to receive(:run_git_command).and_return("No response")
      allow_any_instance_of(JiraHelper::Git).to receive(:run_git_command)
                            .with("git branch -r | grep #{invalid_branch}", anything).and_return("")
      allow_any_instance_of(JiraHelper::Git).to receive(:run_git_command)
                            .with("git branch -r | grep #{valid_branch}", anything).and_return("origin/#{valid_branch}")
    end

    it 'reply show no branch found if can not find any branch' do
      send_command("cherry_pick_commit OD #{invalid_branch} #{invalid_commit_id}")
      expect(replies.last).to eq("No such branch")
    end

    it 'reply show cherry pick commit failed if can not do cherry pick commit' do
      expected_reply_commit = "*Commits to be cherry picked starting at the top:*\n```\"No response\"```"
      allow_any_instance_of(JiraHelper::Git).to receive(:run_git_command)
                            .with("git cherry-pick -s -x #{invalid_commit_id}", anything)
                            .and_return(`exit 1`)
      send_command("cherry_pick_commit OD #{valid_branch} #{invalid_commit_id}")
      expect(replies[1]).to eq(expected_reply_commit)
      expect(replies.last).to eq("Auto cherry-picked FAILED, try again manually")
    end

    it 'reply show cherry pick commit successfully if doing cherry picks succeeds' do
      expected_reply_commit = "*Commits to be cherry picked starting at the top:*\n```\"No response\"```"
      allow_any_instance_of(JiraHelper::Git).to receive(:run_git_command)
                            .with("git cherry-pick -s -x #{valid_commit_id}", anything).and_return(`pwd`)
      send_command("cherry_pick_commit OD #{valid_branch} #{valid_commit_id}")
      expect(replies[1]).to eq(expected_reply_commit)
      expect(replies.last).to eq("Cherry-pick was a success")
    end
  end

  describe '#filter_prod_build' do

    before(:each) do
      @app_versions_arr = ["A2.8.0",
                           "2.8.0.4083.170528.0357.d.226d444 (16)",
                           "UNKNOWN",
                           "2.8.0.4093.170530.2332.d.3f70fae (6)",
                           "2.7.0.91.170504.1948.d.a449bc2 (3)",
                           "2.8.0.4083.170528.0328.d.226d444 (546)",
                           "2.6.0.11.123123.0328.d.123a234 (11)"]
    end

    it "shows sorted app_versions >= prod_version when is_prod_env = True" do
      prod_version = "2.7.0"
      is_prod_env = true
      output_data = subject.filter_prod_build(prod_version, @app_versions_arr, is_prod_env)
      expected_data = "2.8.0.4093.170530.2332.d.3f70fae (6)"\
                      "\n2.8.0.4083.170528.0357.d.226d444 (16)"\
                      "\n2.8.0.4083.170528.0328.d.226d444 (546)"\
                      "\n2.7.0.91.170504.1948.d.a449bc2 (3)"
      expect(output_data).to eq(expected_data)
    end

    it "shows sorted app_versions > prod_version when is_prod_env = False" do
      prod_version = "2.7.0"
      is_prod_env = false
      output_data = subject.filter_prod_build(prod_version, @app_versions_arr, is_prod_env)
      expected_data = "2.8.0.4093.170530.2332.d.3f70fae (6)"\
                      "\n2.8.0.4083.170528.0357.d.226d444 (16)"\
                      "\n2.8.0.4083.170528.0328.d.226d444 (546)"
      expect(output_data).to eq(expected_data)
    end

    it "shows empty list when prod_version > all items in app_versions_arr" do
      prod_version = "2.9.0"
      is_prod_env = true
      output_data = subject.filter_prod_build(prod_version, @app_versions_arr, is_prod_env)
      expect(output_data).to eq("")
    end
  end
  
  describe '#get_das_version' do

    it 'DAS command will repsonse "Project name: argument_project is not valid." if 
        argument_project is invalid' do
      
      project_name = "Cozmo1"
      app_id = "2.6.0"
      build_id = "4042"
          
      send_command("DAS #{project_name} #{app_id} #{build_id}")
      expect(replies.last .eql? 'Project name: Cozmo1 is not valid.').to be true
    end

    it 'DAS command will repsonse No das_version was found error message if 
        project is valid but no das was found in report' do

      project_name = "Cozmo"
      app_id = "2.6.0"
      build_id = "40423123"

      redirect_html = '<html><body>You are being <a href="https://modeanalytics.com/anki/reports/88d38b9bf27c/runs/9626862ab65f"'\
                      '>redirected</a>.</body></html>'
      report_json_data = '{"_links":{"self":{"href":"/api/anki/reports/88d38b9bf27c/runs/9626862ab65f?embed[result]=1"}}}'
      no_das_found_message = "No das_version was found with the given credentials App_ID = #{app_id} "\
                             "and Build ID = #{build_id} in project #{project_name} . Be sure that you "\
                             "entered the correct information and try again"
      stub_request(:any, /param_period=PERIOD/).to_return(:status => 200, :body => redirect_html)
      stub_request(:any, /api/).to_return(:status => 200, :body => report_json_data)
      stub_request(:any, /content.csv/).to_return(:status => 200, :body => "")
      send_command("DAS #{project_name} #{app_id} #{build_id}")
      expect(replies.last .eql? no_das_found_message).to be true
    end

    it 'DAS command will repsonse multiple das_version was found message if 
        more than one das_version was found' do

      project_name = "Cozmo"
      app_id = "2.6.0"
      build_id = "4042"

      redirect_html = '<html><body>You are being <a href="https://modeanalytics.com/anki/reports/88d38b9bf27c/runs/3c23c956f5b9"'\
                      '>redirected</a>.</body></html>'
      report_json_data = '{"_links":{"self":{"href":"/api/anki/reports/88d38b9bf27c/runs/3c23c956f5b9?embed[result]=1"}}}'
      multi_das_found_message = "DAS versions appear in more than one database, but should appear in just one. "\
                                "This may be an issue with a build ID being used multiple times. "\
                                "This may cause issues, so contact a build engineer."
      table_str = "app,platform\n2.6.0.4042.180503.2344.d.f723bca624,android\n2.6.0.4042.180503.2259.d.f723bca624,ios"

      stub_request(:any, /param_period=PERIOD/).to_return(:status => 200, :body => redirect_html)
      stub_request(:any, /api/).to_return(:status => 200, :body => report_json_data)
      stub_request(:any, /content.csv/).to_return(:status => 200, :body => table_str)
      send_command("DAS #{project_name} #{app_id} #{build_id}")
      expect(replies.last).to include(multi_das_found_message)
    end
  end
  
  describe '#jira_description_formatting' do

    it 'The known specific characters are replaced correctly' do
      input_data = "&lt;-u0026lt;-&gt;-u0026gt;-&amp;-u0026amp;"
      expected_data = "<-<->->-&-&"
      output_data = subject.jira_description_formatting input_data
      expect(output_data).to eq(expected_data)
    end
  end

  describe '#jira_summary_formatting' do

    it 'is replaced correctly with specific characters' do
      input_specific_characters = "&lt;-u0026lt;-&gt;-u0026gt;-&amp;-u0026amp;"
      expected_data = "<-<->->-&-&"
      output_data = subject.jira_summary_formatting input_specific_characters
      expect(output_data).to eq(expected_data)
    end

    it 'only first 251 characters will be kept' do
      input_more_251_characters = "0123456789" * 26
      expected_data = input_more_251_characters[0..250]
      output_data = subject.jira_summary_formatting input_more_251_characters
      expect(output_data).to eq(expected_data)
    end
  end
  
  describe '#jql_search_formatting' do

    it 'all special characters will be replaced correctly' do
      input = "&lt;u0026lt;&gt;u0026gt;&amp;u0026amp;-?[](){}*!\\'"
      expected = "<<>>&&\\\\-\\\\?\\\\[\\\\]\\\\(\\\\)\\\\{\\\\}\\\\*\\\\!\\\\\\'"
      output = subject.jql_search_formatting input
      expect(output).to eq(expected)
    end

    it 'only first 231 characters will be kept' do
      #Create a string to get output > 231 characters
      input = "0123456789" * 24
      expected = input[0..230]
      output = subject.jql_search_formatting input
      expect(output).to eq(expected)
    end
  end
  
  describe '#get_affects_versions' do

    it 'returns an expected array of full affect versions with correct format and items in this array are unique' do
      affect_version_list = ["2.8.0.4093.170530.2332.d.3f70fae (6)",
                             "2.8.0.4083.170528.0357.d.226d444 (16)",
                             "2.8.0.4083.170528.0328.d.226d444 (546)",
                             "2.7.0.91.170504.1948.d.a449bc2 (3)"]
      project_name_string = "OD"
      expected_list = ["#{project_name_string} 2.8.0",
                       "#{project_name_string} 2.7.0"]
      output_list = subject.get_affects_versions(affect_version_list, project_name_string)
      expect(output_list).to eq(expected_list)
    end

    it 'returns that exact string if inputting a specific' do
      affect_version_list = ["2.2.0 (12)",
                             "2.8.0.4083.170528.0357.d.226d444 (16)",
                             "2.7.0.91.170504.1948.d.a449bc2 (3)"]
      project_name_string = "OD"
      expected_list = ["#{project_name_string} 2.2.0",
                       "#{project_name_string} 2.8.0",
                       "#{project_name_string} 2.7.0"]
      output_list = subject.get_affects_versions(affect_version_list, project_name_string)
      expect(output_list).to eq(expected_list)
    end
  end

  describe '#update_bots' do

    it 'reply show update command is executing if 
        allowed_update_users includes response.user.id' do
        allowed_user = Lita::User.create('U17B8V7CZ', name: "Allowed User")
        allow_any_instance_of(Lita::Handlers::Jira).to receive(:`).and_return(true)
        send_command('update_bots', as: allowed_user)
        expect(replies.last).to eq("Your request is executing, please wait....")
    end

    it 'reply show user id is not in the approved list to update the bots if 
        allowed_update_users does not include response.user.id' do
        user_id = 'U17B8V7CZABC'
        not_allowed_user = Lita::User.create(user_id, name: "Not allowed User")
        send_command('update_bots', as: not_allowed_user)
        expect(replies.last).to eq("User ID #{user_id} is not in the approved list to update the bots")
    end
  end
  
  describe '#get_project_from_version' do
    it 'Check that entire input is returned if version does not contains space' do
      input = "XYZ987"
      result = subject.get_project_from_version(input)
      expect(result).to eq(input)
    end

    it 'Check that left part before space is returned if version contains space' do
      input = "XYZ 123"
      result = subject.get_project_from_version(input)
      expect(result).to eq("XYZ")
    end
  end

  describe '#all_affected_version' do

    it 'returns an expected affected_versions string for inputted issue' do
      expected_affect_version = subject.all_affected_version(saved_issue_with_fewer_details_affect_version)
      expect(expected_affect_version).to eq(", 1.0.0, 1.0.1, 1.0.2")
    end

    it 'returns empty if issue has not affected version' do
      expected_affect_version = subject.all_affected_version(saved_issue_with_fewer_details_not_affect_version)
      expect(expected_affect_version).to eq("")
    end
  end

  describe '#get_real_version' do

    it 'returns only first characters which locate in before space if inputting a string that has 1 space' do
      affect_version_string = "2.8.0.4093.170530.2332.d.3f70fae (6)"
      expected_string = "2.8.0.4093.170530.2332.d.3f70fae"
      output_string = subject.get_real_version(affect_version_string)
      expect(output_string).to eq(expected_string)
    end

    it 'returns that exact string if inputting a string without space' do
      affect_version_string = "2.8.0.4093.170530.2332.d.3f70fae"
      expected_string = affect_version_string
      output_string = subject.get_real_version(affect_version_string)
      expect(output_string).to eq(expected_string)
    end
  end
  
  describe '#current_crash_count' do

    it 'current_crash_count.to_i return expected number of crash' do
      grab_request(valid_client)
      crash_count = subject.current_crash_count('XYZ-987')
      expect(crash_count.to_i).to eq(12)
    end

    it 'current_crash_count.to_i return 0 if issue has no crash' do
      grab_request(invalid_client)
      crash_count = subject.current_crash_count('XYZ-987')
      expect(crash_count.to_i).to eq(0)
    end
  end

  describe '#release_list_no_closed' do
    it 'release_list_no_closed shows list of issue summaries if jql has issues returned' do
      expected_reply = "<https://jira.local/browse/XYZ-987|XYZ-987>: In Progress\n"\
                       "<https://jira.local/browse/XYZ-988|XYZ-988>: In Progress 2\n"
      grab_request(valid_client)
      send_command('jirareleasecp XYZ ABC')
      expect(replies.last).to eq(expected_reply)
    end

    it 'release_list_no_closed shows error message if jql return an exception' do
      grab_request(failed_find_issues)
      send_command('jirareleasecp XYZ ABC')
      expect(replies.last).to eq("Error fetching JIRA issue")
    end

    it 'release_list_no_closed shows empty message if jql return an empty issue list' do
      grab_request(empty_search_result)
      send_command('jirareleasecp XYZ ABC')
      expect(replies.last).to eq("")
    end
  end

  describe '#create_or_comment' do
    before do
      $stderr = File.open(File::NULL, "w")
      $stdout = File.open(File::NULL, "w")
      @command_text = '{"text":"New Crash Group for OverDrive-Android-Playstore https://fakes.hockeyapp.net/manage/apps/226612/crash_reasons/113995091",' \
                       '"username":"",' \
                       '"bot_id":"",' \
                       '"icons":{},' \
                       '"attachments":[{"fields":['\
                                                    '{"title":"Platform",'\
                                                     '"value":"Android",'\
                                                     '"short":true},'\
                                                    '{"title":"Release Type",'\
                                                     '"value":"Non_Store",'\
                                                     '"short":true},'\
                                                    '{"title":"Version",'\
                                                     '"value":"1.2.0 (109)",'\
                                                     '"short":false},'\
                                                    '{"title":"Location",'\
                                                     '"value":"libmono.002b29b4",'\
                                                     '"short":false},'\
                                                    '{"title":"Reason",'\
                                                     '"value":"java.lang.Error: signal 11 (SIGSEGV),'\
                                                        'code 1 (SEGV_MAPERR), fault addr a29ad9e0",'\
                                                     '"short":false}'\
                                                  ']}]}'
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:get_hockeyapp_crash_apprun).with(anything).and_return("apprun")
    end

    it "shows text 'hockeyappissues.invalid_release'"\
       "if Gem::Version.new raise Error," do
      command_text = @command_text.gsub("1.2.0 (109)","invalid_version")
      send_command(command_text)
      expect(replies.last).to eq("<!here> Someone is playing with the invalid `` release build.")
    end

    it "shows text 'release.excluded'"\
       "if affects_version <= exclude_gem_version and exclude_project_name == jira_project" do
      registry.config.handlers.common.jira.production_version = "OD 1.2.0"
      send_command(@command_text)
      expect(replies.last).to eq("The 1.2.0 release is excluded from bot processing, ignoring.")
    end

    it "shows text: hockeyappissues.affects_version_undef_jira" do
      registry.config.handlers.common.jira.production_version = "XYZ 1.1.0"
      registry.config.handlers.common.jira.projects = "{'OverDrive'=>'XYZ'}"
      expected_error_message = "<!here> The `XYZ 1.2.0` affects version is not defined in JIRA. `XYZ 1.2.0` crashes will not be processed until that is done."
      grab_request(failed_issue_build)
      send_command(@command_text)
      expect(replies.last).to eq(expected_error_message)
    end

    it "response.reply shows text: hockeyappissues.new" do
      registry.config.handlers.common.jira.production_version = "XYZ 1.1.0"
      registry.config.handlers.common.jira.projects = "{'OverDrive'=>'XYZ'}"
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:hockeyapp_jira_link).and_return(true)
      expected_message = "This is a new issue, logged as https://jira.local/browse/XYZ-987"
      grab_request(filtered_no_issue)
      send_command(@command_text)
      expect(replies.last).to eq(expected_message)
    end

    context "Issues are closed with 'Cannot Reproduce' resolution" do
      let(:saved_issue1) do
        result = double(summary: 'Some summary text',
                        assignee: double(displayName: 'A Person'),
                        fields: {'fixVersions' => [{ 'name' => 'Sprint 2.0.0' }],
                                 'status' => {'name' => 'Closed'},
                                 'resolution' => {'name' => 'Cannot Reproduce'},
                                 'priority' => {'name' => 'Critical'},
                                 'customfield_11404' => {"self"=> "https://test", "value"=> "010", "id"=> "10518"}},
                        key: 'XYZ-987')
        allow(result).to receive_message_chain('status.name') { result.fields['status']['name'] }
        allow(result).to receive(:fixVersions) { result.fields['fixVersions'] }
        allow(result).to receive_message_chain('priority.name') { result.fields['priority']['name'] }
        allow(result).to receive(:customfield_11404) { result.fields['customfield_11404']}
        allow(result).to receive('save') { true }
        allow(result).to receive('save!') { true }
        allow(result).to receive('fetch') { true }
        allow(result).to receive_message_chain('transitions.build').and_return(transition_issue)
        allow(result).to receive_message_chain('comments.build.save!') { true }
        result
      end

      let(:saved_issue2) do
        result = double(summary: 'Some summary text 2',
                        assignee: double(displayName: 'A Person 2'),
                        fields: {'fixVersions' => [{ 'name' => 'Sprint 2.0.0' }],
                                 'status' => {'name' => 'Closed'},
                                 'resolution' => {'name' => 'Cannot Reproduce'},
                                 'priority' => {'name' => 'Critical'},
                                 'customfield_11404' => {"self"=> "https://test", "value"=> "010", "id"=> "10518"}},
                        key: 'XYZ-988')
        allow(result).to receive_message_chain('status.name') { result.fields['status']['name'] }
        allow(result).to receive(:fixVersions) { result.fields['fixVersions'] }
        allow(result).to receive_message_chain('priority.name') { result.fields['priority']['name'] }
        allow(result).to receive(:customfield_11404) { result.fields['customfield_11404'] }
        allow(result).to receive('save') { true }
        allow(result).to receive('save!') { true }
        allow(result).to receive('fetch') { true }
        allow(result).to receive_message_chain('transitions.build').and_return(transition_issue)
        allow(result).to receive_message_chain('comments.build.save!') { true }
        result
      end

      let(:searched_issue) do
        result = [saved_issue1, saved_issue2]
        allow(result).to receive('fetch') { true }
        result
      end

      let(:valid_client_for_issue) do
        issue = double
        max_result = registry.config.handlers.common.jira.max_results.to_i
        query_options_stop = {:fields => [],
                              :start_at => max_result,
                              :max_results => max_result}
        allow(issue).to receive_message_chain('Issue.jql') { searched_issue }
        allow(issue).to receive_message_chain('Issue.jql').with(anything(), query_options_stop) { [] }
        issue
      end

      it "Issues are re-opened message should be displayed when reopening ticket" do
        grab_request(valid_client_for_issue)
        command_line = '{"text":"New Crash Group for OverDrive-Android-Playstore https://local.net/reasons/11391",' \
                         '"username":"HockeyApp",' \
                         '"bot_id":"B50JZ8P9A",' \
                         '"icons":{},' \
                         '"attachments":[{"fields":['\
                                                      '{"title":"Platform",'\
                                                       '"value":"Android",'\
                                                       '"short":true},'\
                                                      '{"title":"Release Type",'\
                                                       '"value":"Store",'\
                                                       '"short":true},'\
                                                      '{"title":"Version",'\
                                                       '"value":"3.5.0 (109)",'\
                                                       '"short":false},'\
                                                      '{"title":"Location",'\
                                                       '"value":"libmono.002b29b4",'\
                                                       '"short":false},'\
                                                      '{"title":"Reason",'\
                                                       '"value":"java.lang.Error: ",'\
                                                       '"short":false}'\
                                                    ']}]}'
        allow_any_instance_of(Lita::Handlers::Jira).to receive(:get_hockeyapp_crash_apprun).and_return("apprun")
        allow_any_instance_of(Lita::Handlers::Jira).to receive(:hockeyapp_jira_link).and_return(true)
        send_command(command_line)
        expect(replies.first).to eq("Re-opening #{searched_issue.first.key}")
      end

      it 'No issue found message should be displayed when finding no issues' do
        grab_request(empty_search_result)
        command_line = '{"text":"New Crash Group for OverDrive-Android-Playstore https://local.net/reasons/11391",' \
                         '"username":"HockeyApp",' \
                         '"bot_id":"B50JZ8P9A",' \
                         '"icons":{},' \
                         '"attachments":[{"fields":['\
                                                      '{"title":"Platform",'\
                                                       '"value":"Android",'\
                                                       '"short":true},'\
                                                      '{"title":"Release Type",'\
                                                       '"value":"Store",'\
                                                       '"short":true},'\
                                                      '{"title":"Version",'\
                                                       '"value":"3.5.0 (109)",'\
                                                       '"short":false},'\
                                                      '{"title":"Location",'\
                                                       '"value":"libmono.002b29b4",'\
                                                       '"short":false},'\
                                                      '{"title":"Reason",'\
                                                       '"value":"java.lang.Error: ",'\
                                                       '"short":false}'\
                                                    ']}]}'
        allow_any_instance_of(Lita::Handlers::Jira).to receive(:get_hockeyapp_crash_apprun).and_return("apprun")
        send_command(command_line)
        expect(replies.last).to eq("No issues were found in STORE release type.")
      end

      it 'The duplicate issue message should be shown with re-opening issues' do
        grab_request(valid_client_for_issue)
        command_line = '{"text":"New Crash Group for OverDrive-Android-Playstore https://local.net/reasons/11391",' \
                         '"username":"HockeyApp",' \
                         '"bot_id":"B50JZ8P9A",' \
                         '"icons":{},' \
                         '"attachments":[{"fields":['\
                                                      '{"title":"Platform",'\
                                                       '"value":"Android",'\
                                                       '"short":true},'\
                                                      '{"title":"Release Type",'\
                                                       '"value":"Store",'\
                                                       '"short":true},'\
                                                      '{"title":"Version",'\
                                                       '"value":"3.5.0 (109)",'\
                                                       '"short":false},'\
                                                      '{"title":"Location",'\
                                                       '"value":"libmono.002b29b4",'\
                                                       '"short":false},'\
                                                      '{"title":"Reason",'\
                                                       '"value":"java.lang.Error: sign",'\
                                                       '"short":false}'\
                                                    ']}]}'
        allow_any_instance_of(Lita::Handlers::Jira).to receive(:get_hockeyapp_crash_apprun).and_return("apprun")
        allow_any_instance_of(Lita::Handlers::Jira).to receive(:hockeyapp_jira_link).and_return(true)
        send_command(command_line)
        expect(replies[1..3]).to eq(["This is a duplicate issue of:",
                                     "<#{registry.config.handlers.common.jira.site}/browse/#{saved_issue1.key}"\
                                     "|#{saved_issue1.key}> #{saved_issue1.summary}\n*Status:* "\
                                     "#{saved_issue1.status.name}, *Assigned To:* #{saved_issue1.assignee.displayName}"\
                                     "\n*Fix Version:* #{saved_issue1.fixVersions.first['name']}\n*VIP Category:* "\
                                     "#{saved_issue1.customfield_11404.values[1]}, *Priority:*"\
                                     " #{saved_issue1.priority.name}",
                                     "<#{registry.config.handlers.common.jira.site}/browse/#{saved_issue2.key}"\
                                     "|#{saved_issue2.key}> #{saved_issue2.summary}\n*Status:* "\
                                     "#{saved_issue2.status.name}, *Assigned To:* #{saved_issue2.assignee.displayName}"\
                                     "\n*Fix Version:* #{saved_issue2.fixVersions.first['name']}\n*VIP Category:* "\
                                     "#{saved_issue2.customfield_11404.values[1]}, *Priority:* "\
                                     "#{saved_issue2.priority.name}"])
      end
    end

    context "Issues are closed with 'Done' resolution" do
      let(:saved_issue1) do
        result = double(summary: 'Some summary text',
                        assignee: double(displayName: 'A Person'),
                        fields: {'fixVersions' => [{ 'name' => 'Sprint 2.0.0' }],
                                 'status' => {'name' => 'Closed'},
                                 'resolution' => {'name' => 'Done'},
                                 'priority' => {'name' => 'Critical'},
                                 'customfield_11404' => {"self"=> "https://test", "value"=> "010", "id"=> "10518"}},
                        key: 'XYZ-987')
        allow(result).to receive_message_chain('status.name') { result.fields['status']['name'] }
        allow(result).to receive(:fixVersions) { result.fields['fixVersions'] }
        allow(result).to receive_message_chain('priority.name') { result.fields['priority']['name'] }
        allow(result).to receive(:customfield_11404) { result.fields['customfield_11404']}
        allow(result).to receive('save') { true }
        allow(result).to receive('save!') { true }
        allow(result).to receive('fetch') { true }
        allow(result).to receive_message_chain('transitions.build').and_return(transition_issue)
        allow(result).to receive_message_chain('comments.build.save!') { true }
        result
      end

      let(:saved_issue2) do
        result = double(summary: 'Some summary text 2',
                        assignee: double(displayName: 'A Person 2'),
                        fields: {'fixVersions' => [{ 'name' => 'Sprint 2.0.0' }],
                                 'status' => {'name' => 'Closed'},
                                 'resolution' => {'name' => 'Done'},
                                 'priority' => {'name' => 'Critical'},
                                 'customfield_11404' => {"self"=> "https://test", "value"=> "010", "id"=> "10518"}},
                        key: 'XYZ-988')
        allow(result).to receive_message_chain('status.name') { result.fields['status']['name'] }
        allow(result).to receive(:fixVersions) { result.fields['fixVersions'] }
        allow(result).to receive_message_chain('priority.name') { result.fields['priority']['name'] }
        allow(result).to receive(:customfield_11404) { result.fields['customfield_11404'] }
        allow(result).to receive('save') { true }
        allow(result).to receive('save!') { true }
        allow(result).to receive('fetch') { true }
        allow(result).to receive_message_chain('transitions.build').and_return(transition_issue)
        allow(result).to receive_message_chain('comments.build.save!') { true }
        result
      end

      let(:searched_issue) do
        result = [saved_issue1, saved_issue2]
        allow(result).to receive('fetch') { true }
        result
      end

      let(:valid_client_for_issue) do
        issue = double
        max_result = registry.config.handlers.common.jira.max_results.to_i
        query_options_stop = {:fields => [],
                              :start_at => max_result,
                              :max_results => max_result}
        allow(issue).to receive_message_chain('Issue.find') { saved_issue }
        allow(issue).to receive_message_chain('Issue.find.comments.build.save!') { saved_issue }
        allow(issue).to receive_message_chain('Issue.build') { saved_issue }
        allow(issue).to receive_message_chain('Project.find') { saved_project }
        allow(issue).to receive_message_chain('Issue.jql') { searched_issue }
        allow(issue).to receive_message_chain('Issue.jql').with(anything(), query_options_stop) { [] }
        issue
      end

      it 'Issues are re-opened message should be displayed when reopening ticket' do
        grab_request(valid_client_for_issue)
        command_line = '{"text":"New Crash Group for OverDrive-Android-Playstore https://local.net/113995091",' \
                         '"username":"HockeyApp",' \
                         '"bot_id":"B50JZ8P9A",' \
                         '"icons":{},' \
                         '"attachments":[{"fields":['\
                                                      '{"title":"Platform",'\
                                                       '"value":"Android",'\
                                                       '"short":true},'\
                                                      '{"title":"Release Type",'\
                                                       '"value":"Store",'\
                                                       '"short":true},'\
                                                      '{"title":"Version",'\
                                                       '"value":"3.5.0 (109)",'\
                                                       '"short":false},'\
                                                      '{"title":"Location",'\
                                                       '"value":"libmono.002b29b4",'\
                                                       '"short":false},'\
                                                      '{"title":"Reason",'\
                                                       '"value":"java.lang.Error: s",'\
                                                       '"short":false}'\
                                                    ']}]}'

        allow_any_instance_of(Lita::Handlers::Jira).to receive(:get_hockeyapp_crash_apprun).and_return("apprun")
        allow_any_instance_of(Lita::Handlers::Jira).to receive(:hockeyapp_jira_link).and_return(true)
        send_command(command_line)
        expect(replies.first).to eq("Re-opening #{searched_issue.first.key}")
      end
    end
  end

  describe '#contain_exclude_versions' do

    list_exclude_versions = ["4.1","4.2","4.3","4.4","4.5","4.6","4.7","4.8","4.9","5.0"]
    it 'the contain_exclude_versions is true' do
      version= "4.1"
      result = subject.contain_exclude_versions(version,list_exclude_versions)
      expect(result).to eq(true)
    end
    
    it 'the contain_exclude_versions is false when version non-exist' do
      version= "3.3"
      result = subject.contain_exclude_versions(version,list_exclude_versions)
      expect(result).to eq(false)
    end

    it 'the contain_exclude_versions is false when version is empty' do
      version= ""
      result = subject.contain_exclude_versions(version,list_exclude_versions)
      expect(result).to eq(false)
    end
  end

  describe '#exclude_crash_versions' do
    it 'the versions still enable to used to report crash are displayed' do
      master_version='{"app_versions":[{"version":"5062","shortversion":"3.5.0.5062.d3860c7f97.DEV"}]}'
      release_version_android='<html><body><div class="BgcNfc">Current Version</div><span class="htlgb">'\
                              '<div class="BgcNfc"><span class="htlgb">3.4.6</span></div></span></div><div class="hAyfc">'\
                              '</body></html>'
      release_version_ios ='{"results" :[{"version" : "3.4.5"}]}'
      stub_request(:any, /play.google.com/).to_return(:status => 200, :body => release_version_android)
      stub_request(:any, /itunes.apple.com/).to_return(:status => 200, :body => release_version_ios)
      stub_request(:any, /hockeyapp.net/).to_return(:status => 200, :body => master_version)
      expect_result = ["3.4.5", "3.4.6","3.4.7", "3.4.8", "3.4.9", "3.5.0"]
      result = subject.exclude_crash_versions('OD')
      expect(result).to eq(expect_result)
    end
  end

  describe '#jira_description' do

    it 'the error display when issue does not exist' do
      grab_request(failed_find_issue)
      send_command('jira_description XYZ-1')
      expect(replies).to eq(['Error fetching JIRA issue'])
    end

    it 'the description display correctly when issue exists' do
      grab_request(valid_client)
      send_command('jira_description XYZ-987')
      expected_message = "<https://jira.local/browse/XYZ-987|XYZ-987> Some summary text\n"\
                        "*Description:* This is description of issue"
      expect(replies.last).to eq(expected_message)
    end
  end

  describe '#create_release_tickets' do
    before do
      @ticket_data = '{"tickets" :'\
                              '[{'\
                                '"task" : "cut-branch",'\
                                '"project" : "XYZ",'\
                                '"watchers" : ["persion_1","persion_2","persion_3"],'\
                                '"assignee" : "chapados",'\
                                '"description" : "Branch off Master to update the Release Candidate branch."'\
                              '}]}'
      @command_text = "create_release_tickets XYZ 1.7.0"
    end

    it 'replies hockeyappissues.new_release_ticket message if project is correct' do
      expected_resut = "XYZ 1.7.0 task: cut-branch, logged as "\
                       "#{registry.config.handlers.common.jira.site}/browse/XYZ-987"
      allow(File).to receive(:read).and_return(@ticket_data)
      grab_request(valid_client_create_task)
      stub_request(:post, /watchers/).to_return(status: 200, body: "")
      send_command(@command_text)
      expect(replies.last).to eq(expected_resut)
    end

    it 'replies hockeyappissues.create_tickets_issue message if project is incorrect' do
      expected_err_msg = "There was a problem creating release tickets. undefined method `key' for nil:NilClass"
      grab_request(failed_find_project)
      allow(File).to receive(:read).and_return(@ticket_data)
      send_command(@command_text)
      expect(replies.last).to eq(expected_err_msg)
    end
  end

  describe '#cherry_pick_do_it' do
    valid_branch  = "valid-branch"
    valid_issue   = "XYZ-987"
    commits_empty = {'branch' => [], 'picked' => [], 'to_pick' => []}
    commits       = {'branch' => ["branch"], 'picked' => ["picked"], 'to_pick' => ["to_pick"]}

    before do
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:fetch_issue).and_return("#{valid_issue}")
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:get_project_from_issue).and_return("#{valid_issue}".split[0])
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:set_git_name).and_return(true)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:set_git_email).and_return(true)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:fetch_repo).and_return(true)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:change_and_update_branch).and_return(true)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:get_jira_repos).and_return(true)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:branch_exists).and_return(true)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:get_commits_to_cherry_pick).and_return(commits)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:create_commit_list).with(commits['branch'])
                                                                                 .and_return(valid_branch)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:create_commit_list).with(commits['picked'])
                                                                                 .and_return("picked")
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:create_commit_list_with_summary).and_return("cherry_pick")
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:do_cherry_pick_list).and_return(false)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:do_git_push).and_return(true)
    end

    it 'responds "git.no_branch" when branch_exists method returns false' do
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:branch_exists).and_return(false)
      send_command("cherry_pick_do_it #{valid_branch} #{valid_issue}")
      expect(replies.last).to eq("No such branch")
    end

    it 'responds "error.no_commits" when branch, picked, to_pick arrays are empty' do
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:get_commits_to_cherry_pick).and_return(commits_empty)
      send_command("cherry_pick_do_it #{valid_branch} #{valid_issue}")
      expect(replies.last).to eq("*No commits exist*")
    end

    it 'responds "git.branched" when branch array does not empty' do
      send_command("cherry_pick_do_it #{valid_branch} #{valid_issue}")
      expect(replies[1]).to eq("Already in branch:\n```#{valid_branch}```")
    end

    it 'responds "git.picked" when picked array does not empty' do
      send_command("cherry_pick_do_it #{valid_branch} #{valid_issue}")
      expect(replies[2]).to eq("Already cherry-picked:\n```picked```")
    end

    it 'responds "git.cherry_pick" when to_pick array does not empty' do
      send_command("cherry_pick_do_it #{valid_branch} #{valid_issue}")
      expect(replies[3]).to eq("*Commits to be cherry picked starting at the top:*\n```cherry_pick```")
    end

    it 'responds "git.cherry_pick_failure" when do_cherry_pick_list method returns fail' do
      send_command("cherry_pick_do_it #{valid_branch} #{valid_issue}")
      expect(replies.last).to eq("Auto cherry-picked FAILED, try again manually")
    end

    it 'responds "git.cherry_pick_success" when do_cherry_pick_list method returns true' do
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:do_cherry_pick_list).and_return(true)
      send_command("cherry_pick_do_it #{valid_branch} #{valid_issue}")
      expect(replies.last).to eq("Cherry-pick was a success")
    end
  end

  describe '#fetch_issue' do
    issue_key = "XYZ-987"
    issue_summary = "Summary text for fetch_issue function"

    let(:saved_issue_that_fetch) do
      result = double(summary: "#{issue_summary}",
                      key: "#{issue_key}")
      result
    end

    let(:valid_client) do
      issue = double
      allow(issue).to receive_message_chain('Issue.find').with("#{issue_key}") { saved_issue_that_fetch }
      issue
    end

    let(:invalid_client) do
      issue = double
      allow(issue).to receive_message_chain('Issue.find').with("#{issue_key}")
                                                         .and_raise(StandardError.new("connection error"))
      issue
    end

    it 'return valid issue when fetching correct pattern issue' do
      grab_request(valid_client)
      issue = subject.fetch_issue("#{issue_key}")
      expect(issue.summary).to eq("#{issue_summary}")
    end

    it 'return valid issue when fetching incorrect pattern issue' do
      grab_request(valid_client)
      issue = subject.fetch_issue("XYZ987")
      expect(issue.summary).to eq("#{issue_summary}")
    end

    it 'return nil when having unexpected problem connecting Jira site' do
      grab_request(invalid_client)
      issue = subject.fetch_issue("#{issue_key}")
      expect(issue).to eq(nil)
    end
  end

  describe '#get_hockeyapp_crash_apprun' do
    before do
      @url = "https://fakes.hockeyapp.net/manage/apps/123/crash_reasons/456"
      apps_data = '{"apps": [{"id":"123", "public_identifier":"abc"},'\
                                   '{"id":"456", "public_identifier":"xyz"}]}'
      crashes_data = '{"crashes":[{"id":"abc-123"}]}'
      stub_request(:get, /api\/2/).to_return(:status => 200, :body => apps_data)
      stub_request(:get, /crash_reasons/).to_return(:status => 200, :body => crashes_data)
    end

    it "returns correct crash apprun if it's found with hockeyapp_crash_url has 'format=text'" do
      expect_result = "ABCXYZ-12"
      apprun_data = '{"apprun": "ABCXYZ-12"}'
      stub_request(:get, /format.*text/).to_return(:status => 200, :body => apprun_data)
      value = subject.get_hockeyapp_crash_apprun(@url)
      expect(value).to eq(expect_result)
    end

    it "returns correct crash apprun if it's found with hockeyapp_crash_url has 'format=log'" do
      expect_result = "ABCXYZ-12"
      apprun_data = 'apprun: ABCXYZ-12'
      invalid_data = ''
      stub_request(:get, /format.*text/).to_return(:status => 200, :body => invalid_data)
      stub_request(:get, /format.*log/).to_return(:status => 200, :body => apprun_data)
      value = subject.get_hockeyapp_crash_apprun(@url)
      expect(value).to eq(expect_result)
    end

    it "returns 'no apprun found' if crash apprun isn't found" do
      expect_result = "no apprun found"
      invalid_data = ''
      stub_request(:get, /format.*text/).to_return(:status => 200, :body => invalid_data)
      stub_request(:get, /format.*log/).to_return(:status => 200, :body => invalid_data)
      value = subject.get_hockeyapp_crash_apprun(@url)
      expect(value).to eq(expect_result)
    end
  end

  describe '#fetch_issues' do
    issues_jql = "PROJECT = 'XXX' AND Summary~'Some summary text' ORDER BY status ASC"

    it 'return the list of issues found in jql query' do
      grab_request(filtered_has_issue)
      result = subject.fetch_issues(issues_jql)
      expect(result).to eq(valid_search_results)
    end

    it 'return issues is nil if jql returns an exception' do
      grab_request(failed_find_issues)
      result = subject.fetch_issues(issues_jql)
      expect(result).to eq(nil)
    end

    it 'return empty list if no issues found in jql query' do
      grab_request(filtered_no_issue)
      result = subject.fetch_issues(issues_jql)
      expect(result).to eq([])
    end
  end

  describe '#update_affects_version' do

    it 'invalid_affects_versions is empty if all_affect_versions has updated successfully' do
      input_affected_version = ["1.0.2", "1.0.3"]
      expected_result = ""
      all_affects_versions = ["1.0.0", "1.0.1"]
      updated_affects_versions = ["1.0.0", "1.0.1", "1.0.2", "1.0.3"]
      allow_any_instance_of(JiraHelper::Jira).to receive(:add_affects_version).and_return(true)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:all_affected_version)
                                                  .and_return(all_affects_versions, updated_affects_versions)
      grab_request(valid_client)
      result = subject.update_affects_version(saved_issue, input_affected_version)
      expect(result).to eq(expected_result)
    end

    it 'invalid_affects_versions is empty if all input_affected_version have existed in all_affect_versions' do
      input_affected_version = ["1.0.1", "1.0.2"]
      expected_result = ""
      all_affects_versions = ["1.0.0", "1.0.1", "1.0.2"]
      updated_affects_versions = ["1.0.0", "1.0.1", "1.0.2"]
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:all_affected_version)
                                                .and_return(all_affects_versions, updated_affects_versions)
      grab_request(valid_client)
      result = subject.update_affects_version(saved_issue, input_affected_version)
      expect(result).to eq(expected_result)
    end

    it 'invalid_affects_versions contains unavailable affected versions in jira' do
      input_affected_version = ["0.0.0", "1.0.2"]
      expected_result = "\nAffects versions are not available in Jira:\n0.0.0\n"
      all_affects_versions = ["1.0.0", "1.0.1"]
      updated_affects_versions = ["1.0.0", "1.0.1", "1.0.2"]
      allow_any_instance_of(JiraHelper::Jira).to receive(:add_affects_version).and_return(false)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:all_affected_version)
                                                .and_return(all_affects_versions, updated_affects_versions)
      grab_request(valid_client)
      result = subject.update_affects_version(saved_issue, input_affected_version)
      expect(result).to eq(expected_result)
    end
  end

  describe '#handle_special_jql' do

    project = "BI"

    it 'return jql with summary is splitted if the summary contains non-word characters' do
      summary = "A-B!C.D"
      expected_result = "PROJECT = '#{project}' AND Summary~'A' AND Summary~'B' AND Summary~'C' AND Summary~'D'" \
                        " ORDER BY Summary"
      result = subject.handle_special_jql(project, summary)
      expect(result).to eq(expected_result)
    end

    it 'returns jql with original summary if the summary not contain non-word characters' do
      summary = "ABCD"
      expected_result = "PROJECT = '#{project}' AND Summary~'#{summary}' ORDER BY Summary"
      result = subject.handle_special_jql(project, summary)
      expect(result).to eq(expected_result)
    end

    it 'return jql with summary is splitted correctly if the summary contains two consecutive non-word characters' do
      summary = "A-BC`!D"
      expected_result = "PROJECT = '#{project}' AND Summary~'A' AND Summary~'BC' AND Summary~'D' ORDER BY Summary"
      result = subject.handle_special_jql(project, summary)
      expect(result).to eq(expected_result)
    end
  end

  describe '#cherry_pick' do
    branch_name   = "branch_name"
    issue_id      = "ABC-123"
    commits_empty = {'branch' => [], 'picked' => [], 'to_pick' => []}
    commits       = {'branch' => ["branch"], 'picked' => ["picked"], 'to_pick' => ["to_pick"]}
    command_text  = "cherry_pick #{branch_name} #{issue_id}"

    before do
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:fetch_issue).and_return("#{issue_id}")
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:get_project_from_issue).and_return("#{issue_id}".split[0])
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:fetch_repo).and_return(true)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:change_and_update_branch).and_return(true)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:get_jira_repos).and_return(true)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:branch_exists).and_return(true)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:get_commits_to_cherry_pick).and_return(commits)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:create_commit_list).with(commits['branch'])
                                                                                 .and_return(branch_name)
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:create_commit_list).with(commits['picked'])
                                                                                 .and_return("picked")
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:create_commit_list_with_summary).and_return("cherry_pick")
    end

    it 'responds "git.no_branch" when branch_exists method returns false' do
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:branch_exists).and_return(false)
      expected_result = "No such branch"
      send_command(command_text)
      expect(replies.last).to eq(expected_result)
    end

    it 'responds "error.no_commits" when branch, picked, to_pick arrays are empty' do
      allow_any_instance_of(Lita::Handlers::Jira).to receive(:get_commits_to_cherry_pick).and_return(commits_empty)
      expected_result = "*No commits exist*"
      send_command(command_text)
      expect(replies.last).to eq(expected_result)
    end

    it 'responds full messages when branch array does not empty' do
      expected_result = ["Fetching, please wait...",
                         "Already in branch:\n```#{branch_name}```",
                         "Already cherry-picked:\n```picked```",
                         "*Commits to be cherry picked starting at the top:*\n```cherry_pick```"]
      send_command(command_text)
      expect(replies).to eq(expected_result)
    end
  end

  describe '#format_issue_pr' do

    it "return both iOS and android pull request if build_info has both iOS and Android info" do
      pull_requests = [{"id"=>"#123456","url"=>"https://github.com/123456"}]
      build_info = {"ios"=>"XXX_PullRequestsIOS", "android"=>"XXX_PullRequestAndroid", "branch"=>"XXX"}
      expected_result = "<https://jira.local/browse/XYZ-987|XYZ-987> Some summary text\n*Status:* In Progress,"\
                        " *Pull Requests:* \n<https://github.com/123456|#123456>"\
                        "  <https://teamcity_uri.com/viewType.html?buildTypeId=XXX_PullRequestsIOS&"\
                        "branch_XXX_Dev=123456%2Fhead&tab=buildTypeStatusDiv|iOS>"\
                        "  <https://teamcity_uri.com/viewType.html?buildTypeId=XXX_PullRequestAndroid&"\
                        "branch_XXX_Dev=123456%2Fhead&tab=buildTypeStatusDiv|Android> \n\n"
      allow_any_instance_of(JiraHelper::Issue).to receive(:get_build_info_from_key).and_return(build_info)
      result = subject.format_issue_pr(pull_requests, saved_issue)
      expect(result).to eq(expected_result)
    end

    it "return iOS pull request if build_info has iOS info only" do
      pull_requests = [{"id"=>"#123456","url"=>"https://github.com/123456"}]
      build_info = {"ios"=>"XXX_PullRequestsIOS", "android"=>"", "branch"=>"XXX"}
      expected_result = "<https://jira.local/browse/XYZ-987|XYZ-987> Some summary text\n*Status:* In Progress,"\
                        " *Pull Requests:* \n<https://github.com/123456|#123456>"\
                        "  <https://teamcity_uri.com/viewType.html?buildTypeId=XXX_PullRequestsIOS&"\
                        "branch_XXX_Dev=123456%2Fhead&tab=buildTypeStatusDiv|iOS>  \n"
      allow_any_instance_of(JiraHelper::Issue).to receive(:get_build_info_from_key).and_return(build_info)
      result = subject.format_issue_pr(pull_requests, saved_issue)
      expect(result).to eq(expected_result)
    end

    it "return android pull request if build_info has android info only" do
      pull_requests = [{"id"=>"#123456","url"=>"https://github.com/123456"}]
      build_info = {"ios"=>"", "android"=>"XXX_PullRequestAndroid", "branch"=>"XXX"}
      expected_result = "<https://jira.local/browse/XYZ-987|XYZ-987> Some summary text\n*Status:* In Progress,"\
                        " *Pull Requests:* \n<https://github.com/123456|#123456>"\
                        "  <https://teamcity_uri.com/viewType.html?buildTypeId=XXX_PullRequestAndroid&"\
                        "branch_XXX_Dev=123456%2Fhead&tab=buildTypeStatusDiv|Android> \n\n"
      allow_any_instance_of(JiraHelper::Issue).to receive(:get_build_info_from_key).and_return(build_info)
      result = subject.format_issue_pr(pull_requests, saved_issue)
      expect(result).to eq(expected_result)
    end

    it "return pull request info is empty if pull_requests is empty" do
      pull_requests = []
      build_info = {"ios"=>"XXX_PullRequestsIOS", "android"=>"XXX_PullRequestAndroid", "branch"=>"XXX"}
      expected_result = "<https://jira.local/browse/XYZ-987|XYZ-987> Some summary text\n*Status:* In Progress," \
                        " *Pull Requests:* \n\n"
      allow_any_instance_of(JiraHelper::Issue).to receive(:get_build_info_from_key).and_return(build_info)
      result = subject.format_issue_pr(pull_requests, saved_issue)
      expect(result).to eq(expected_result)
    end

    it "return message 'No pull requests' if build_info is empty" do
      pull_requests = [{"id"=>"#123456","url"=>"https://github.com/123456"}]
      build_info = ""
      expected_result = "<https://jira.local/browse/XYZ-987|XYZ-987> Some summary text\n*Status:* In Progress," \
                        " *Pull Requests:* No pull requests\n"
      allow_any_instance_of(JiraHelper::Issue).to receive(:get_build_info_from_key).and_return(build_info)
      result = subject.format_issue_pr(saved_pullrequest_has_data, saved_issue)
      expect(result).to eq(expected_result)
    end
  end

  describe '#get_jira_commits_in_master' do

    it "return correct data if repositories has commits and id" do
      repositories = [{'commits'=>['id'=>'123','app'=>'OD']},{'commits'=>['id'=>'456']}]
      expected_result = ['123', '456']
      allow_any_instance_of(JiraHelper::Git).to receive(:commit_in_branch).and_return(true)
      result = subject.get_jira_commits_in_master(repositories, "location")
      expect(result).to eq(expected_result)
    end

    it "return empty if repositories has no commits and id" do
      repositories = [{'commits'=>['app'=>'OD']}]
      expected_result = []
      allow_any_instance_of(JiraHelper::Git).to receive(:commit_in_branch).and_return(false)
      result = subject.get_jira_commits_in_master(repositories, "location")
      expect(result).to eq(expected_result)
    end
  end

  describe '#last_updated_day' do

    it 'returns empty day if the issue do not have any comments' do
      allow_any_instance_of(JiraHelper::Jira).to receive(:last_comment).and_return(nil)
      result = subject.last_updated_day(saved_issue)
      expect(result).to eq("")
    end

    it 'returns the last updated day if the issue contains any comments' do
      last_comment = {'body'=> "abc",'updated' => "2018-10-08T19:14:17.466"}
      allow_any_instance_of(JiraHelper::Jira).to receive(:last_comment).and_return(last_comment)
      result = subject.last_updated_day(saved_issue)
      expect(result).to eq("10/08/18")
    end
  end

  describe '#content_last_comment' do

    it 'returns empty content if the issue do not have any comments' do
      allow_any_instance_of(JiraHelper::Jira).to receive(:last_comment).and_return(nil)
      result = subject.content_last_comment(saved_issue)
      expect(result).to eq("")
    end

    it 'returns the last updated day if the issue contains any comments' do
      last_comment = {'body'=> "This is content",'updated' => "2018-10-08T19:14:17.466-0700"}
      allow_any_instance_of(JiraHelper::Jira).to receive(:last_comment).and_return(last_comment)
      result = subject.content_last_comment(saved_issue)
      expect(result).to eq("This is content")
    end
  end

  describe '#do_cherry_pick' do
    commit = "commit"
    branch = "branch"
    location = "location"
    git_cherry_pick_command = "git cherry-pick -s -x #{commit}"
    git_reset_command = "git reset --hard origin #{branch}"

    it 'reply false if doing run_git_command unsuccessfully' do
      allow_any_instance_of(JiraHelper::Git).to receive(:run_git_command)
                                            .with(git_cherry_pick_command, location)
                                            .and_return(`exit 1`)
      allow_any_instance_of(JiraHelper::Git).to receive(:run_git_command)
                                            .with(git_reset_command, location)
                                            .and_return("")
      result = subject.do_cherry_pick(commit, branch, location)
      expect(result).to eq(false)
    end

    it 'reply true if doing run_git_command successfully' do
      allow_any_instance_of(JiraHelper::Git).to receive(:run_git_command)
                                            .with(git_cherry_pick_command, location)
                                            .and_return(`pwd`)
      result = subject.do_cherry_pick(commit, branch, location)
      expect(result).to eq(true)
    end

  end

  describe '#convert_to_readable_time' do
    it "return 'week' value if num_of_day is 7" do
      num_of_day = 7
      result = subject.convert_to_readable_time(num_of_day)
      expect(result).to eq("week")
    end

    it "return 'month' value if num_of_day >= 28 and num_of_day <= 31" do
      num_of_day = 29
      result = subject.convert_to_readable_time(num_of_day)
      expect(result).to eq("month")
    end

    it "return 'year' value if num_of_day = 365 or num_of_day = 366" do
      num_of_day = 365
      result = subject.convert_to_readable_time(num_of_day)
      expect(result).to eq("year")
    end

    it "return correct number of day if num_of_day is not in above cases" do
      num_of_day = 123
      expected_result = "#{num_of_day} days"
      result = subject.convert_to_readable_time(num_of_day)
      expect(result).to eq(expected_result)
    end
  end

  describe '#update_jira_with_mode_report_data' do
    json_data = [{'occurrences'=>'7',
                 'event'=>'1',
                 'app'=>'OD',
                 'sample_apprun'=>'sample_apprun',
                 'level'=>'level',
                 'jiraid'=>'jiraid',
                 'notes'=>'notes'}]
    json_empty = nil

    project = "OD"
    period = "day"
    site = "DEV"
    large_number_occurrences = "8"
    small_number_occurrences = "6"
    labels = "errors"
    log_warning = ""
    is_prod_env = "false"

    let(:fetch_issues) do
      result = [double(summary: 'Some summary text',
                       assignee: double(displayName: 'A Person'),
                       priority: double(name: 'P0'),
                       status: double(name: 'In Progress'),
                       project: {"id" => "1", "key" => "XYZ", "name" => "XYZ"},
                       fields: {'status' => {'name' => 'In Progress'}},
                       description: 'This is description of issue',
                       id: '111111',
                       key: 'XYZ-987',
                       labels: {'triage' => 'true'},
                       comments: double(build: '1.2.3'))]
      result
    end

    let(:issue_fields) do
      result = {'versions' => [{ 'name' => '1.0.0' },
                               { 'name' => '1.0.1' },
                               { 'name' => '1.0.2' }],
                'status' => {'name' => 'Closed'}}
    end

    let(:fetch_issues_closed) do
      result = double(summary: 'Some summary text',
                      assignee: double(displayName: 'A Person'),
                      priority: double(name: 'P0'),
                      status: double(name: 'In Progress'),
                      project: {"id" => "1", "key" => "XYZ", "name" => "XYZ"},
                      fields: "",
                      description: 'This is description of issue',
                      id: '111111',
                      key: 'XYZ-987',
                      labels: {'triage' => 'true'},
                      transitions: "")
      allow(result).to receive_message_chain('first.key').and_return('XYZ-987')
      allow(result).to receive_message_chain('first.transitions.build').and_return(transition_issue)
      allow(result).to receive_message_chain("first.fields").and_return(issue_fields)
      result
    end

    it 'response nill json_data if the input json_data is nill' do
      expected_result = nil
      result = subject.update_jira_with_mode_report_data(json_empty, project, period, site, large_number_occurrences,
                                                         labels, log_warning, is_prod_env)
      expect(result).to eq(expected_result)
    end

    it 'response correct json_data if number_occurrences is greater than occurrences' do
      expected_result = [{"occurrences" => "7", "event" => "1", 
                          "app"=>"", "sample_apprun"=>"sample_apprun", 
                          "level"=>"level", "jiraid"=>"", 
                          "notes"=>"Occurrences not satisfied"}]
      allow_any_instance_of(JiraHelper::Issue).to receive(:fetch_issues).and_return(fetch_issues)
      result = subject.update_jira_with_mode_report_data(json_data, project, period, site, large_number_occurrences,
                                                         labels, log_warning, is_prod_env)
      expect(result).to eq(expected_result)
    end

    it 'response correct json_data if app is null or ks_issue is true' do
      expected_result = [{"occurrences" => "7", "event" => "1", 
                          "app" => "", "sample_apprun" => "sample_apprun", 
                          "level" => "level", "jiraid" => "", 
                          "notes" => "Occurs on old build version, ignoring."}]
      allow_any_instance_of(JiraHelper::Issue).to receive(:fetch_issues).and_return(fetch_issues)
      allow_any_instance_of(JiraHelper::Jira).to receive(:check_ks_issue).and_return(false)
      result = subject.update_jira_with_mode_report_data(json_data, project, period, site, small_number_occurrences,
                                                         labels, log_warning, is_prod_env)
      expect(result).to eq(expected_result)
    end

    it 'response correct json_data if app is not null and ks_issue is faise' do
      expected_result = [{"occurrences" => "7", "event" => "1", 
                          "app" => "#{project}", "sample_apprun" => "sample_apprun", 
                          "level" => "level", "jiraid" => "XYZ-987", 
                          "notes" => "Added comment"}]
      allow_any_instance_of(JiraHelper::Issue).to receive(:fetch_issues).and_return(fetch_issues)
      allow_any_instance_of(JiraHelper::Jira).to receive(:check_ks_issue).and_return(false)
      allow_any_instance_of(JiraHelper::Jira).to receive(:filter_prod_build).and_return(project)
      allow_any_instance_of(JiraHelper::Jira).to receive(:does_attachment_exist).and_return(true)
      allow_any_instance_of(JiraHelper::Jira).to receive(:add_comment).and_return("")
      allow_any_instance_of(JiraHelper::Issue).to receive(:update_affects_version).and_return("")
      result = subject.update_jira_with_mode_report_data(json_data, project, period, site, small_number_occurrences,
                                                         labels, log_warning, is_prod_env)
      expect(result).to eq(expected_result)
    end

    it 'response correct json_data if app is not null and ks_issue is faise' do
      expected_result = [{"occurrences" => "7", "event" => "1", 
                          "app" => "#{project}", "sample_apprun" => "sample_apprun", 
                          "level" => "level", "jiraid" => "XYZ-987", 
                          "notes" => "Reopened"}]
      allow_any_instance_of(JiraHelper::Issue).to receive(:fetch_issues).and_return(fetch_issues_closed)
      allow_any_instance_of(JiraHelper::Jira).to receive(:check_ks_issue).and_return(false)
      allow_any_instance_of(JiraHelper::Jira).to receive(:filter_prod_build).and_return(project)
      allow_any_instance_of(JiraHelper::Jira).to receive(:does_attachment_exist).and_return(true)
      allow_any_instance_of(JiraHelper::Jira).to receive(:add_comment).and_return("")
      allow_any_instance_of(JiraHelper::Jira).to receive(:add_affects_version).and_return("")
      allow_any_instance_of(JiraHelper::Issue).to receive(:update_affects_version).and_return("")
      result = subject.update_jira_with_mode_report_data(json_data, project, period, site, small_number_occurrences,
                                                         labels, log_warning, is_prod_env)
      expect(result).to eq(expected_result)
    end
  end

  describe '#git_uri' do
    it 'response empty git_uri if repo is not equal to COZMO or OD' do
      expected_result = ""
      result = subject.git_uri("Vic")
      expect(result).to eq(expected_result)
    end

    it 'response config.jira.git_uri_od if repo is OD' do
      expected_result = "git@github.com:/company/a.git"
      result = subject.git_uri("OD")
      expect(result).to eq(expected_result)
    end

    it 'response config.jira.git_uri_cozmo if repo is COZMO' do
      expected_result = "git@github.com:/company/b.git"
      result = subject.git_uri("COZMO")
      expect(result).to eq(expected_result)
    end
  end

  describe '#generate_jira_error_description' do
    time_data = Time.parse("2018-11-11 11:11:11")
    time_day = "November-10-2018"
    time_week = "November-04-2018"
    apprun = "apprun"
    occurrences = "123"
    app = "app"
    prod_site = "prod"
    dev_beta_site = "DEV/BETA"

    before do
      allow(Time).to receive(:new) { time_data }
    end

    it "return day message with 'attach_apprun_log' if 'add_logfile' is 'true' and 'period' is 'day'" do
      add_logfile = true
      period = "day"
      expected_result = "#{occurrences} occurrences on #{time_day} on PROD.\n" \
                        "@apprunbot apprun #{apprun}\n" \
                        "Build version: #{app}."
      result = subject.generate_jira_error_description(apprun, occurrences, app, period, prod_site, add_logfile)
      expect(result).to eq(expected_result)
    end

    it "return week message with 'attach_apprun_log' if 'add_logfile' is 'true' and 'period' is not 'day" do
      add_logfile = true
      period = "week"
      expected_result = "#{occurrences} occurrences from #{time_week} to" \
                        "#{time_day}.\n" \
                        "@apprunbot apprun #{apprun}\n" \
                        "Build version: #{app}."
      result = subject.generate_jira_error_description(apprun, occurrences, app, period, prod_site, add_logfile)
      expect(result).to eq(expected_result)
    end

    it "return day message with 'no_apprun_log' if 'add_logfile' is 'false' and 'period' is 'day" do
      add_logfile = false
      period = "day"
      expected_result = "#{occurrences} occurrences on #{time_day} on #{dev_beta_site}.\n" \
                        "Apprun: #{apprun}.\nBuild version: #{app}."
      result = subject.generate_jira_error_description(apprun, occurrences, app, period, dev_beta_site, add_logfile)
      expect(result).to eq(expected_result)
    end

    it "return week message with 'no_apprun_log' if 'add_logfile' is 'false' and 'period' is not 'day" do
      add_logfile = false
      period = "week"
      expected_result = "#{occurrences} occurrences from #{time_week} to" \
                        "#{time_day}.\n" \
                        "Apprun: #{apprun}.\nBuild version: #{app}."
      result = subject.generate_jira_error_description(apprun, occurrences, app, period, dev_beta_site, add_logfile)
      expect(result).to eq(expected_result)
    end
  end

  describe '#get_commits_to_cherry_pick' do
    location = 'valid_location'
    master_name = 'master'
    branch_name = 'branch_XYZ_Dev'
    valid_data = 'valid_data'
    empty_data = ''

    it 'returns correct commits if "commit_in_branch", "cherry_picked" or "merged_commit" not empty' do
      commit_id_1 = "xxxxxx2018_1"
      commit_id_2 = "xxxxxx2018_2"
      commit_id_3 = "xxxxxx2018_3"
      parent_commit_id_1 = "xxxxxx2017"
      parent_commit_id_2 = "xxxxxx2016"
      parent_commit_id_3 = "xxxxxx2015"
      merge_base = "xxxxxx2013"
      commit_id_list = "unexpected_result #{parent_commit_id_2} #{parent_commit_id_3}"
      to_merge = "xxxxxx2014 #{parent_commit_id_3}"
      commits_in_merge = ["xxxxxx2014", parent_commit_id_3]
      expected_result = {"branch" => [commit_id_1], "picked" => [commit_id_2], "to_pick" => commits_in_merge}
      repositories = [{"commits" => [{"id" => commit_id_1}, {"id" => commit_id_2}, {"id" => commit_id_3}]}]

      #fake data for 'get_jira_commits_in_master' function
      input_commit_id_list = [commit_id_1, commit_id_2, commit_id_3]
      input_commit_id_list.each do |commit_id|
        stub_run_git_command(commit_in_branch_command(commit_id, master_name), location, valid_data)
      end

      #fake data for 'commit_in_branch' function
      stub_run_git_command(commit_in_branch_command(commit_id_1, branch_name), location, valid_data)
      stub_run_git_command(commit_in_branch_command(commit_id_2, branch_name), location, empty_data)
      stub_run_git_command(commit_in_branch_command(commit_id_3, branch_name), location, empty_data)

      #fake data for 'cherry_picked' function
      stub_run_git_command(cherry_picked_command(branch_name, commit_id_2), location, valid_data)
      stub_run_git_command(cherry_picked_command(branch_name, commit_id_3), location, empty_data)

      #fake data for 'get_merged_commit' function
      stub_run_git_command(get_merged_commit_command(commit_id_3), location, parent_commit_id_1)

      #fake data for 'commits_in_merge' function
      stub_run_git_command(get_parents_of_merge_commit_command(parent_commit_id_1), location, commit_id_list)
      stub_run_git_command(find_diverged_of_commits_command(parent_commit_id_2, parent_commit_id_3),
                                                            location, merge_base)
      stub_run_git_command(get_commits_between_two_commits_command(merge_base, parent_commit_id_3), location, to_merge)

      value = subject.get_commits_to_cherry_pick(repositories, branch_name, location)
      expect(value).to eq(expected_result)
    end

    it 'returns commits in "jira_commits_in_master"'\
       'if "commit_in_branch", "cherry_picked" and "merged_commit" are empty' do
      commit_id = "xxxxxx2018"
      expected_result = {"branch" => [], "picked" => [], "to_pick" => [commit_id]}
      repositories = [{"commits" => [{"id" => commit_id}]}]

      #fake data for 'get_jira_commits_in_master' function
      stub_run_git_command(commit_in_branch_command(commit_id, master_name), location, valid_data)

      #fake data for 'commit_in_branch' function
      stub_run_git_command(commit_in_branch_command(commit_id, branch_name), location, empty_data)

      #fake data for 'cherry_picked' function
      stub_run_git_command(cherry_picked_command(branch_name, commit_id), location, empty_data)

      #fake data for 'get_merged_commit' function
      stub_run_git_command(get_merged_commit_command(commit_id), location, empty_data)

      value = subject.get_commits_to_cherry_pick(repositories, branch_name, location)
      expect(value).to eq(expected_result)
    end
  end

  describe '#create_issue' do
    valid_project   = "XYZ-987"
    summary         = "Some summary text"
    description     = "This is description of issue"
    default_type    = "error"
    affects_version = "1.0.0"
    assignee        = "Person A"
    watchers        = [{"self" => "https://jira.local/rest/api/2/user?username=ABC"},\
                      {"self" => "https://jira.local/rest/api/2/user?username=XYZ"}]

    it 'returns nil if the project does not exist' do
      invalid_project = "ABC-123"
      grab_request(failed_find_project)
      issue = subject.create_issue(invalid_project, summary, description, default_type, affects_version, assignee,
                                   watchers)
      expect(issue).to eq(nil)
    end

    it 'returns nil if issue type is invalid' do
      invalid_issue_type = "story"
      grab_request(valid_client)
      issue = subject.create_issue(valid_project, summary, description, invalid_issue_type, affects_version, assignee,
                                   watchers)
      expect(issue).to eq(nil)
    end

    it 'returns nil if issue returns an exception' do
      grab_request(failed_save_issue)
      issue = subject.create_issue(valid_project, summary, description, default_type, affects_version, assignee,
                                   watchers)
      expect(issue).to eq(nil)
    end

    it 'returns a crash issue if the project exists and type == "crash"' do
      issue_type = "crash"
      expected_result = saved_issue
      grab_request(valid_client)
      issue = subject.create_issue(valid_project, summary, description, issue_type, affects_version, assignee, watchers)
      expect(issue).to eq(expected_result)
    end

    it 'returns an error issue_id if the project exists and type == "error"' do
      issue_type = "error"
      expected_result = "XYZ-987"
      grab_request(valid_client)
      issue_id = subject.create_issue(valid_project, summary, description, issue_type, affects_version, assignee,
                                      watchers)
      expect(issue_id).to eq(expected_result)
    end

    it 'returns an task issue if the project exists and type == "task"' do
      issue_type = "task"
      expected_result = saved_issue
      grab_request(valid_client)
      stub_request(:post, /watchers/).to_return(:status => 200)
      issue = subject.create_issue(valid_project, summary, description, issue_type, affects_version, assignee, watchers)
      expect(issue).to eq(expected_result)
    end
  end

  describe '#get_last_release_version_android' do

    it 'the last android version release return correctly' do
      expect_result = "3.4.0"
      result = subject.get_last_release_version_android('OD')
      expect(result).to eq(expect_result)
    end
  end
  
  describe '#get_vector_events' do

    it 'the reply message is "Event `event_type` is not valid." if event_type is not supported' do
      invalid_event_type = "abc"
      send_command("vector_events #{invalid_event_type}")
      expect(replies.last).to eq("Event `#{invalid_event_type}` is not valid.")
    end

    it 'the reply message is "No versions." if event_type is supported but not have any data' do
      valid_event_type = "app"
      allow_any_instance_of(Lita::Handlers::Mode).to receive(:get_data_from_mode_by_time_period).and_return("")
      send_command("vector_events #{valid_event_type}")
      expect(replies.last).to eq("No versions.")
    end

    it 'the reply message contains all app_version, platform, event_count if event_type is supported and have data' do
      valid_event_type = "app"
      json_data = [{"app_version" => "1.0.0", "platform" => "android", "event_count" => "111"}]
      expected_result = "*app_version* : 1.0.0, *platform* : android, *event_count* : 111\n"
      allow_any_instance_of(Lita::Handlers::Mode).to receive(:get_data_from_mode_by_time_period).and_return(json_data)
      send_command("vector_events #{valid_event_type}")
      expect(replies.last).to eq(expected_result)
    end
  end
  
  describe '#update_jira_with_mode_report_data' do
    json_data = [{'occurrences'=>'7',
                 'event'=>'1',
                 'app'=>'OD',
                 'sample_apprun'=>'sample_apprun',
                 'level'=>'level',
                 'jiraid'=>'jiraid',
                 'notes'=>'notes'}]
    json_data_invalid = nil

    project = "OD"
    period = "day"
    site = "DEV"
    large_number_occurrences = "8"
    small_number_occurrences = "6"
    labels = "errors"
    log_warning = ""
    is_prod_env = "false"

    let(:fetch_issues) do
      result = [double(summary: 'Some summary text',
                       assignee: double(displayName: 'A Person'),
                       priority: double(name: 'P0'),
                       status: double(name: 'In Progress'),
                       project: {"id" => "1", "key" => "XYZ", "name" => "XYZ"},
                       fields: {'status' => {'name' => 'In Progress'}},
                       description: 'This is description of issue',
                       id: '111111',
                       key: 'XYZ-987',
                       labels: {'triage' => 'true'},
                       comments: double(build: '1.2.3'))]
      result
    end

    let(:issue_fields) do
      result = {'versions' => [{ 'name' => '1.0.0' },
                               { 'name' => '1.0.1' },
                               { 'name' => '1.0.2' }],
                'status' => {'name' => 'Closed'}}
    end

    let(:fetch_issues_closed) do
      result = double(summary: 'Some summary text',
                      assignee: double(displayName: 'A Person'),
                      priority: double(name: 'P0'),
                      status: double(name: 'In Progress'),
                      project: {"id" => "1", "key" => "XYZ", "name" => "XYZ"},
                      fields: "",
                      description: 'This is description of issue',
                      id: '111111',
                      key: 'XYZ-987',
                      labels: {'triage' => 'true'},
                      transitions: "")
      allow(result).to receive_message_chain('first.key').and_return('XYZ-987')
      allow(result).to receive_message_chain('first.transitions.build').and_return(transition_issue)
      allow(result).to receive_message_chain("first.fields").and_return(issue_fields)
      result
    end

    it 'response nil json_data if the input json_data is nil' do
      expected_result = nil
      result = subject.update_jira_with_mode_report_data(json_data_invalid, project, period, site,
                                                         large_number_occurrences,
                                                         labels, log_warning, is_prod_env)
      expect(result).to eq(expected_result)
    end

    it 'response correct json_data if number_occurrences is greater than occurrences' do
      expected_result = [{"occurrences" => "7", "event" => "1", 
                          "app"=>"", "sample_apprun"=>"sample_apprun", 
                          "level"=>"level", "jiraid"=>"", 
                          "notes"=>"Occurrences not satisfied"}]
      allow_any_instance_of(JiraHelper::Issue).to receive(:fetch_issues).and_return(fetch_issues)
      result = subject.update_jira_with_mode_report_data(json_data, project, period, site, large_number_occurrences,
                                                         labels, log_warning, is_prod_env)
      expect(result).to eq(expected_result)
    end

    it 'response correct json_data if app is null or ks_issue is true' do
      expected_result = [{"occurrences" => "7", "event" => "1", 
                          "app" => "", "sample_apprun" => "sample_apprun", 
                          "level" => "level", "jiraid" => "", 
                          "notes" => "Occurs on old build version, ignoring."}]
      allow_any_instance_of(JiraHelper::Issue).to receive(:fetch_issues).and_return(fetch_issues)
      allow_any_instance_of(JiraHelper::Jira).to receive(:check_ks_issue).and_return(false)
      result = subject.update_jira_with_mode_report_data(json_data, project, period, site, small_number_occurrences,
                                                         labels, log_warning, is_prod_env)
      expect(result).to eq(expected_result)
    end

    it 'response correct json_data if app is not null and ks_issue is false' do
      expected_result = [{"occurrences" => "7", "event" => "1", 
                          "app" => "#{project}", "sample_apprun" => "sample_apprun", 
                          "level" => "level", "jiraid" => "XYZ-987", 
                          "notes" => "Added comment"}]
      allow_any_instance_of(JiraHelper::Issue).to receive(:fetch_issues).and_return(fetch_issues)
      allow_any_instance_of(JiraHelper::Jira).to receive(:check_ks_issue).and_return(false)
      allow_any_instance_of(JiraHelper::Jira).to receive(:filter_prod_build).and_return(project)
      allow_any_instance_of(JiraHelper::Jira).to receive(:does_attachment_exist).and_return(true)
      allow_any_instance_of(JiraHelper::Jira).to receive(:add_comment).and_return("")
      allow_any_instance_of(JiraHelper::Issue).to receive(:update_affects_version).and_return("")
      result = subject.update_jira_with_mode_report_data(json_data, project, period, site, small_number_occurrences,
                                                         labels, log_warning, is_prod_env)
      expect(result).to eq(expected_result)
    end

    it 'response correct json_data if app is not null and ks_issue is false' do
      expected_result = [{"occurrences" => "7", "event" => "1", 
                          "app" => "#{project}", "sample_apprun" => "sample_apprun", 
                          "level" => "level", "jiraid" => "XYZ-987", 
                          "notes" => "Reopened"}]
      allow_any_instance_of(JiraHelper::Issue).to receive(:fetch_issues).and_return(fetch_issues_closed)
      allow_any_instance_of(JiraHelper::Jira).to receive(:check_ks_issue).and_return(false)
      allow_any_instance_of(JiraHelper::Jira).to receive(:filter_prod_build).and_return(project)
      allow_any_instance_of(JiraHelper::Jira).to receive(:does_attachment_exist).and_return(true)
      allow_any_instance_of(JiraHelper::Jira).to receive(:add_comment).and_return("")
      allow_any_instance_of(JiraHelper::Jira).to receive(:add_affects_version).and_return("")
      allow_any_instance_of(JiraHelper::Issue).to receive(:update_affects_version).and_return("")
      result = subject.update_jira_with_mode_report_data(json_data, project, period, site, small_number_occurrences,
                                                         labels, log_warning, is_prod_env)
      expect(result).to eq(expected_result)
    end
  end

  describe '#execute_daily_weekly_email_report' do

    it 'replies "help.report.error" if "argument_period" or "argument_env" is invalid' do
      argument_platform = "invalid"
      argument_env = "invalid"
      argument_period = "invalid"
      expected_message = "Invalid command!\n`mode_report` `project` `dev` | `prod` `day` | `week`"
      send_command("mode_report #{argument_platform} #{argument_env} #{argument_period}")
      expect(replies.last).to eq(expected_message)
    end

    it 'replies "Runtime exception" message if jsonData.include? "#{RUNTIME_EXCEPTION_PREFIX_MESSAGE}"' do
      argument_platform = "overdrive"
      argument_env = "prod"
      argument_period = "day"
      html_data = "<html><body>You are being" \
                  "<a href=\"https://fakemode.com/anki/reports/just4test/runs/"\
                  "just4test2\">redirected</a>.</body></html>"
      data = '{"_links":{"self":{"href":"/api/anki/reports/just4test/runs'\
             '/just4test2?embed[result]=1"}}}'
      invalid_data = "invalid"
      expected_message = "Runtime exception : error"
      stub_request(:get, /fakemode.com\/anki/).to_return(:status => 200, :body => html_data)
      stub_request(:get, /fakemode.com\/api\/anki/).to_return(:status => 200, :body => data)
      stub_request(:get, /content.csv/).to_return(:status => 200, :body => invalid_data)
      allow_any_instance_of(ModeHelper::Mode).to receive(:convert_data_to_json_format)
                                             .and_raise(StandardError.new("error"))
      send_command("mode_report #{argument_platform} #{argument_env} #{argument_period}")
      expect(replies.last).to eq(expected_message)
    end

    it 'replies "request.timeout" if timeout error' do
      expected_message = "Your request timed out. Please retry the request!"
      argument_platform = "overdrive"
      argument_env = "prod"
      argument_period = "day"
      stub_request(:get, /fakemode.com\/anki/).and_raise(Timeout::Error)
      send_command("mode_report #{argument_platform} #{argument_env} #{argument_period}")
      expect(replies.last).to eq(expected_message)
    end
  end

  describe '#get_vector_error_reason_by_code' do
    before do
      ota_recovery_error_codes = "|   0  | TEST_CODE_A |\n"
      robot_screen_error_codes = "enum : uint16_t {\n"\
                                 "TEST_CODE_B = 1,\n"\
                                 "COUNT = 1000\n"
      playpen_failure_error_codes = "enum uint_8 FactoryTestResultCode {\n"\
                                    "TEST_CODE_C,\n"\
                                    "NO MORE SPACE"
      stub_request(:get, /error-codes.md/).to_return(:status => 200, :body => ota_recovery_error_codes)
      stub_request(:get, /faultCodes.h/).to_return(:status => 200, :body => robot_screen_error_codes)
      stub_request(:get, /factoryTestTypes.clad/).to_return(:status => 200, :body => playpen_failure_error_codes)
    end

    it "replies correct error reason if it matches to error code" do
      expected_message = ["OTA / Recovery Error Codes\n"\
                          "reason: TEST_CODE_A",\
                          "Playpen Failure Codes\n"\
                          "reason: TEST_CODE_C"]
      send_command("vector_error_code 0")
      expect(replies).to eq(expected_message)
    end

    it "replies 'vector_code.code_not_found' if reason.empty?" do
      expected_message = "Vector error code not found."
      send_command("vector_error_code 100")
      expect(replies.last).to eq(expected_message)
    end
  end

  describe '#check_ks_issue' do

     it 'returns ks_issue = false if the issue does not contain VIP category' do
      issue = double(fields: {'customfield_11404' => nil})
      result = subject.check_ks_issue(issue)
      expect(result).to eq(false)
    end

     it 'returns ks_issue = false if the issue does not contain ks_value' do
      issue = double(fields: {'customfield_11404' => {'self'=> 'https://test', 'value'=> '100'}})
      result = subject.check_ks_issue(issue)
      expect(result).to eq(false)
    end

     it 'returns ks_issue = true if the issue contains ks_value' do
      issue = double(fields: {'customfield_11404' => {'self'=> 'https://test', 'value'=> '001'}})
      result = subject.check_ks_issue(issue)
      expect(result).to eq(true)
    end
  end

  describe '#get_app_ids' do

    it 'returns correct build_ids' do
      project = 'project_id_1'
      hockeyapp_app_ids = '{"project_id_1": "hash_id_1", "project_id_2": "hash_id_2"}'
      data = '{"app_versions": [{"shortversion": "3.5.0.5066.aaa.DEV", "id": 4360},'\
             '{"shortversion": "3.5.0.5063.bbb.DEV", "id": 4359},'\
             '{"shortversion": "3.4.0.5057.ccc.DEV", "id": 4361},'\
             '{"shortversion": "3.5.0.5111.ddd.DEV", "id": 4362}]}'
      expect_ids = {'hash_id_1' => [4359, 4360]}
      stub_request(:get, /app_versions/).to_return(:status => 200, :body => data)
      build_ids = subject.get_app_ids(project, hockeyapp_app_ids)
      expect(build_ids).to eq(expect_ids)
    end
  end

  describe '#fetch_issues_by_filter_id' do

    it "return correct data if id is valid" do
      grab_request(filtered_has_issue)
      result = subject.fetch_issues_by_filter_id("id1")
      expect(result).to eq(valid_search_results)
    end

    it "return empty if could not connect to Jira" do
      id = "12345"
      expected_result = []
      stub_request(:get, /12345/).to_raise(StandardError.new("connection error"))
      result = subject.fetch_issues_by_filter_id(id)
      expect(result).to eq(expected_result)
    end
  end

  describe '#update_top_jira_crashes' do
    it "replies 'Updated <ticket_urls> to <number> crashes.' when we call update_top_jira_crashes" do
      ID = 112311
      expected_result = saved_issue
      grab_request(valid_client)
      all_master_ids = {"5caab2c" => [4355]}
      crash_count_old = 3
      expected_result = "Updated https://jira.local/browse/XYZ to 8 crashes."
      data2 = "{\"crash_reason\":{\"id\":#{ID}, \"ticket_urls\":[\"https://jira.local/browse/XYZ\"]}}"
      data1 = "{\"crash_reasons\":[{\"id\":#{ID}, \"number_of_crashes\":8}]}"
      allow_any_instance_of(JiraHelper::Jira).to receive(:get_all_master_ids).and_return(all_master_ids)
      allow_any_instance_of(JiraHelper::Jira).to receive(:current_crash_count).and_return(crash_count_old)
      stub_request(:get, /number_of_crashes/).to_return(:status => 200, :body => data1)
      stub_request(:get, /XYZ/).to_return(:status => 200, :body => expected_result)
      stub_request(:get, /#{ID}/).to_return(:status => 200, :body => data2)
      send_command("update_crash_counts")
      expect(replies.last).to eq (expected_result)
    end
  end  
end
