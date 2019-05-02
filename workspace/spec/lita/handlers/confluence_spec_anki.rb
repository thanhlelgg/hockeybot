require 'spec_helper'

describe Lita::Handlers::Confluence, lita_handler: true do

  before do
    registry.config.handlers.common.jira.projects  = "{'test'=>'TEST'}"
  end

  describe '#release_schedule' do
    data_with_multiple_item = [
                                {"td"=>[
                                  {"style"=>"text-align: right;", "h5"=>"TEST 1.1"}, 
                                  {"style"=>"text-align: right;", "h5"=>"5/6/17"}, 
                                  {"style"=>"text-align: right;", "h5"=>"6/2/17"}, 
                                  {"style"=>"text-align: right;", "h5"=>"6/5/17"}
                                ]}, 
                                {"td"=>[
                                  {"style"=>"text-align: right;", "h5"=>"TEST 2.0"}, 
                                  {"style"=>"text-align: right;", "h5"=>"8/7/18"}, 
                                  {"style"=>"text-align: right;", "h5"=>"8/8/19"}, 
                                  {"style"=>"text-align: right;", "h5"=>"8/9/20"}
                                ]}
                              ]
    data_with_one_item = [
                          {"td"=>[
                            {"style"=>"text-align: right;", "h5"=>"TEST 1.1"}, 
                            {"style"=>"text-align: right;", "h5"=>"5/6/17"}, 
                            {"style"=>"text-align: right;", "h5"=>"6/2/17"}, 
                            {"style"=>"text-align: right;", "h5"=>"6/5/17"}
                          ]}
                         ]
    data_without_item = []
    first_schedule_info = "branch 5/6/17, submit 6/2/17, release 6/5/17"
    second_schedule_info = "branch 8/7/18, submit 8/8/19, release 8/9/20"

    it 'shows all Release Schedules if only argument value is {Project}' do
      expectedOutput = "Release Schedule for TEST :"\
                       "\nTEST 1.1 #{first_schedule_info}"\
                       "\nTEST 2.0 #{second_schedule_info}"
      allow_any_instance_of(Lita::Handlers::Confluence).to receive(:get_release_schedule).and_return(data_with_multiple_item)
      send_command('dates test')
      expect(replies.last).to eq(expectedOutput)
    end

    it 'shows all Release Schedules if arguments are {Project} and {Version}' do
      expectedOutput = "Release Schedule for TEST 1.1 :"\
                       "\nTEST 1.1 #{first_schedule_info}"
      allow_any_instance_of(Lita::Handlers::Confluence).to receive(:get_release_schedule).and_return(data_with_one_item)
      send_command('dates test 1.1')
      expect(replies.last).to eq(expectedOutput)
    end

    it "Add new Release Schedule entry if {Project} {Version} doesn't already exist" do
      expectedOutput = "Added release schedule for TEST 3.1 is successful."
      allow_any_instance_of(Lita::Handlers::Confluence).to receive(:get_release_schedule).and_return(data_without_item)
      allow_any_instance_of(Lita::Handlers::Confluence).to receive(:get_current_release_schedule)\
                                                        .and_return(data_with_multiple_item)
      allow_any_instance_of(Lita::Handlers::Confluence).to receive(:convert_string_to_schedule).and_return("")
      allow_any_instance_of(Lita::Handlers::Confluence).to receive(:format_schedule_to_put).and_return("")
      stub_request(:put, /content/).to_return(:status => 200, :body => "")
      send_command("dates test 3.1 #{first_schedule_info}")
      expect(replies.last).to eq(expectedOutput)
    end

    it 'Update Release Schedule entry with new {Release Schedule String} if {Version} exists' do
      expectedOutput = "Updated release schedule for TEST 1.1 is successful."
      allow_any_instance_of(Lita::Handlers::Confluence).to receive(:get_release_schedule).and_return(data_with_one_item)
      allow_any_instance_of(Lita::Handlers::Confluence).to receive(:get_current_release_schedule)\
                                                        .and_return(data_with_multiple_item)
      allow_any_instance_of(Lita::Handlers::Confluence).to receive(:format_schedule_to_put).and_return("")
      stub_request(:put, /content/).to_return(:status => 200, :body => "")
      send_command("dates test 1.1 #{first_schedule_info}")
      expect(replies.last).to eq(expectedOutput)
    end

  end
end

