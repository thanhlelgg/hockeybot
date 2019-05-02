require 'spec_helper'

describe Lita::Handlers::EzOfficeInventory, lita_handler: true do
  valid_email     = "Person_Name@mail.com"
  invalid_email   = "invalid@email.com"
  full_name       = "Person 1"
  invalid_id      = "invalid_id"
  invalid_name    = "invalid_name"
  json_ez_members = '[{"email":"Person_Name@mail.com","full_name":"Person 1"},
                      {"email":"test@mail.com","full_name":"test client"}]'
  json_ez_assets  = '{
                      "assets": [
                                  {
                                    "state":"checked_out",
                                    "name":"Device 1",
                                    "sequence_num":1,
                                    "identifier":"1",
                                    "checkin_due_on":"2018-01-01 00:00:00",
                                    "assigned_to_user_name":"Person 1"
                                  },
                                  {
                                    "state":"checked_out",
                                    "name":"Device 2",
                                    "sequence_num":2,
                                    "identifier":"2",
                                    "checkin_due_on":"2018-01-02 02:02:02",
                                    "assigned_to_user_name":"Person 1"
                                  }
                                ],
                      "total_pages": 1
                     }'
    json_ez_member = '{
                       "assets": [
                                  {
                                    "id":"1",
                                    "email":"Person_Name@mail.com",
                                    "full_name":"Person 1"
                                  }
                                 ]
                      }'
    json_empty_ez_asset = '{"assets": [], "total_pages": 0}'

  before do
    registry.config.handlers.common.jira.ez_office_site  = 'https://site.ezofficeinventory.com/assets'
    registry.config.handlers.common.jira.ez_office_token = 'faketoken'

    stub_request(:get, /members.api/).to_return(:status => 200, :body => json_ez_members)
    stub_request(:get, /filter.api/).to_return(:status => 200, :body => json_ez_assets)
    stub_request(:get, /status=invalid/).to_return(:status => 200, :body => json_empty_ez_asset)
    stub_request(:get, /search=#{invalid_email}/).to_return(:status => 200, :body => json_empty_ez_asset)
    stub_request(:get, /search=#{valid_email}/).to_return(:status => 200, :body => json_ez_member)
    stub_request(:get, /filter_param_val=#{invalid_id}/).to_return(:status => 200, :body => json_empty_ez_asset)
  end

  describe '#filtered_ez_assets_list' do
    before do
      current_time = Time.parse("2018-01-02 10:00:00 -08:00")
      allow(Time).to receive_message_chain(:now).and_return(current_time)
    end

    it 'replies "No devices found from the filter." if no asset was found' do
      expected_message = "No devices found from the filter."
      send_command("ezfilter invalid")
      expect(replies.last).to eq(expected_message)
    end

    it 'replies list all asset if assets were found' do
      expected_message = "\n<#{registry.config.handlers.common.jira.ez_office_site}/1|1 - Device 1>"\
                         "  *AIN*: 1  *Status*: Checked Out  *Assigned to*: Person 1"\
                         "\n<#{registry.config.handlers.common.jira.ez_office_site}/2|2 - Device 2>"\
                         "  *AIN*: 2  *Status*: Checked Out  *Assigned to*: Person 1"\
                         "\n2 devices were found."
      send_command("ezfilter not_overdue")
      expect(replies.last).to eq(expected_message)
    end

    it 'filter_status == "overdue" replies with list of all found assets and their overdue days' do
      expected_message = "\n<#{registry.config.handlers.common.jira.ez_office_site}/1|1 - Device 1>"\
                         "  *AIN*: 1  *Status*: Checked Out  *Assigned to*: Person 1"\
                         " Number of days overdue: 1."\
                         "\n<#{registry.config.handlers.common.jira.ez_office_site}/2|2 - Device 2>"\
                         "  *AIN*: 2  *Status*: Checked Out  *Assigned to*: Person 1"\
                         " Number of days overdue: Less than a day.\n2 devices were found."
      send_command("ezfilter overdue")
      expect(replies.last).to eq(expected_message)
    end
  end

  describe '#get_num_overdue_days' do
    asset = JSON.parse('{"checkin_due_on":"2018-01-01 00:00:00"}')

    it 'get_num_overdue_days helper method return 0 if the time between current time and checkin_due_on is less than a day' do
      current_time = Time.parse("2018-01-01 10:00:00 -08:00")
      allow(Time).to receive_message_chain(:now, :getlocal).and_return(current_time)
      overdue_days = subject.get_num_overdue_days(asset)
      expect(overdue_days).to eq(0)
    end

    it 'get_num_overdue_days helper method return overdue days correctly if local time is in PST.' do
      current_time = Time.parse("2018-01-03 23:00:00 -08:00")
      allow(Time).to receive_message_chain(:now, :getlocal).and_return(current_time)
      overdue_days = subject.get_num_overdue_days(asset)
      expect(overdue_days).to eq(2)
    end

    it 'get_num_overdue_days helper method return overdue days correctly if local time is in UTC.' do
      current_time = Time.parse("2018-01-03 18:00:00 +00:00")
      allow(Time).to receive_message_chain(:now, :getlocal).and_return(current_time)
      overdue_days = subject.get_num_overdue_days(asset)
      expect(overdue_days).to eq(2)
    end
  end

  describe '#find_member_by_email' do
    it 'returned empty username if email does not matches' do
      result = subject.find_member_by_email(invalid_email)
      expect(result).to eq("")
    end

    it 'returned correct username if email matches in lower case' do
      actual_result = subject.find_member_by_email("#{valid_email}")
      expected_result = JSON.parse(json_ez_member)['assets'][0]
      expect(actual_result).to eq(expected_result)
    end
  end

  describe '#ez_assets_user_list' do
    non_checkout_user_email = "user_not_checkout_asset@email.com"
    non_checkout_user_name = "non_checkout_name"
    non_checkout_user_id = "non_checkout_id"
    json_ez_user_not_checkout = '{
                                    "assets": [
                                                {
                                                  "id":"non_checkout_id",
                                                  "email":"user_not_checkout_asset@email.com",
                                                  "full_name":"non_checkout_name"
                                                }
                                              ]
                                   }'
    before do
      stub_request(:get, /search=#{non_checkout_user_email}/).to_return(:status => 200, :body => json_ez_user_not_checkout)
      stub_request(:get, /filter_param_val=#{non_checkout_user_id}/).to_return(:status => 200, :body => json_empty_ez_asset)
    end

    it 'returns warning when no user was found' do
      expect_data = "User was not found in EzOffice."
      send_command("ezsearch #{invalid_email}")
      expect(replies.last).to eq(expect_data)
    end

    it 'returns "0 devices are checked out by {full_name}." if user does not checkout any asset' do
      expect_data = "\n0 devices are checked out by #{non_checkout_user_name}."
      send_command("ezsearch #{non_checkout_user_email}")
      expect(replies.last).to eq(expect_data)
    end

    it 'returns total of devices that are checked out by user' do
      expect_data = "\n<#{registry.config.handlers.common.jira.ez_office_site}/1|1 - Device 1>"\
                    "  *AIN*: 1  *Status*: Checked Out  *Assigned to*: Person 1"\
                    "\n<#{registry.config.handlers.common.jira.ez_office_site}/2|2 - Device 2>"\
                    "  *AIN*: 2  *Status*: Checked Out  *Assigned to*: Person 1"\
                    "\n2 devices are checked out by #{full_name}."
      send_command("ezsearch #{valid_email}")
      expect(replies.last).to eq(expect_data)
    end
  end

  describe '#get_assets_by_filter' do

    it 'returns only asset from page 1 when total page is 1' do
      json_ez_assets   = '{"assets":[{"OS Version":"6.0.1","OS":"Android"}],"total_pages":1}'
      json_ez_assets_2 = '{"assets":[{"OS Version":"9.3","OS":"iOS"}]}'
      stub_request(:get, /status=overdue/).to_return(:status => 200, :body => json_ez_assets)
      stub_request(:get, /page=2/).to_return(:status => 200, :body => json_ez_assets_2)

      expect_data = [{"OS Version"=>"6.0.1", "OS"=>"Android"}]
      result      = subject.get_assets_by_filter("#{registry.config.handlers.common.jira.ez_office_site}"\
                                                 "/filter.api?status=overdue")
      expect(result).to eq(expect_data)
    end

    it 'return all assets in all pages if total page is more than one' do
      json_ez_assets   = '{"assets":[{"OS Version":"5.8.2","OS":"Android"}],"total_pages":2}'
      json_ez_assets_2 = '{"assets":[{"OS Version":"10.3","OS":"iOS"}]}'
      stub_request(:get, /status=not_overdue/).to_return(:status => 200, :body => json_ez_assets)
      stub_request(:get, /page=2/).to_return(:status => 200, :body => json_ez_assets_2)

      expect_data = [{"OS Version"=>"5.8.2", "OS"=>"Android"}, {"OS Version"=>"10.3", "OS"=>"iOS"}]
      result      = subject.get_assets_by_filter("#{registry.config.handlers.common.jira.ez_office_site}"\
                                                 "/filter.api?status=not_overdue")
      expect(result).to eq(expect_data)
    end
  end
  
  describe '#get_all_assets_in_ez' do

    it 'returns only asset from page 1 when total page is 1' do
      json_ez_assets   = '{"assets":[{"OS Version":"6.0.1","OS":"Android"}],"total_pages":1}'
      json_ez_assets_2 = '{"assets":[{"OS Version":"9.3","OS":"iOS"}]}'
      stub_request(:get, /assets.api/).to_return(:status => 200, :body => json_ez_assets)
      stub_request(:get, /page=2/).to_return(:status => 200, :body => json_ez_assets_2)

      expect_data = [{"OS Version"=>"6.0.1", "OS"=>"Android"}]
      result      = subject.get_all_assets_in_ez("#{registry.config.handlers.common.jira.ez_office_site}.api")
      expect(result).to eq(expect_data)
    end

    it 'return all assets in all pages if total page is more than one' do
      json_ez_assets   = '{"assets":[{"OS Version":"6.0.1","OS":"Android"}],"total_pages":2}'
      json_ez_assets_2 = '{"assets":[{"OS Version":"9.3","OS":"iOS"}]}'
      stub_request(:get, /assets.api/).to_return(:status => 200, :body => json_ez_assets)
      stub_request(:get, /page=2/).to_return(:status => 200, :body => json_ez_assets_2)

      expect_data = [{"OS Version"=>"6.0.1", "OS"=>"Android"}, {"OS Version"=>"9.3", "OS"=>"iOS"}]
      result      = subject.get_all_assets_in_ez("#{registry.config.handlers.common.jira.ez_office_site}.api")
      expect(result).to eq(expect_data)
    end
  end

  describe '#get_asset_result' do

    it 'return found devices with checked_out status' do
      asset       = {"state"=>"checked_out", "name"=>"iPhone 5s", "identifier"=>"1111",
                     "sequence_num"=>"45", "assigned_to_user_name"=>"Adam Shelly"}
      expect_data = "\n<#{registry.config.handlers.common.jira.ez_office_site}/45|45 - iPhone 5s>  *AIN*: 1111"\
                    "  *Status*: Checked Out  *Assigned to*: Adam Shelly"
      result      = subject.get_asset_result(asset)
      expect(result).to eq(expect_data)
    end

    it 'return found devices with available status' do
      asset       = {"state"=>"available", "name"=>"iPhone 7", "identifier"=>"2222",
                     "sequence_num"=>"45", "assigned_to_user_name"=>"Adam Shelly"}
      expect_data = "\n<#{registry.config.handlers.common.jira.ez_office_site}/45|45 - iPhone 7>  *AIN*: 2222"\
                    "  *Status*: Available"
      result      = subject.get_asset_result(asset)
      expect(result).to eq(expect_data)
    end
  end

  describe '#ez_search_assets' do
    json_ez_assets_2  = '{
                        "assets": [
                                    {
                                      "id":"11111",
                                      "email":"test@mail.com",
                                      "state":"checked_out",
                                      "name":"Device 1",
                                      "sequence_num":1,
                                      "identifier":"1",
                                      "checkin_due_on":"2018-01-01 00:00:00",
                                      "assigned_to_user_name":"Person 1",
                                      "full_name":"test client"
                                    }
                                  ],
                        "total_pages": 1
                       }'

    it 'return all devices that is found matching the email address' do
      expected_message = ["Finding all devices that are checked out for *test client*..."\
                         , "\n<https://site.ezofficeinventory.com/assets/1|1 - Device 1>  "\
                         "*AIN*: 1  *Status*: Checked Out  *Assigned to*: Person 1"\
                         "\n1 devices are checked out by test client."]
      stub_request(:get, /search/).to_return(:status => 200, :body => json_ez_assets_2)
      stub_request(:get, /filter.api/).to_return(:status => 200, :body => json_ez_assets_2)
      send_command("ezsearch test@mail.com")
      expect(replies).to eq(expected_message)
    end

    it 'return message "User was not found in EzOffice." if no members match the query' do
      expected_message = ["User was not found in EzOffice."]
      allow_any_instance_of(Lita::Handlers::EzOfficeInventory).to receive(:find_member_by_email).and_return("")
      send_command("ezsearch test1@mail.com")
      expect(replies).to eq(expected_message)
    end

    it 'return all devices that is found' do
      expected_message = "\n<https://site.ezofficeinventory.com/assets/1|1 - Device 1>"\
                         "  *AIN*: 1  *Status*: Checked Out  *Assigned to*: Person 1"
      stub_request(:get, /search/).to_return(:status => 200, :body => json_ez_assets_2)
      send_command("ezsearch iPhone")
      expect(replies.last).to eq(expected_message)
    end

    it 'return "No devices found matching your query." if do not find any devices matching the query' do
      allow_any_instance_of(Lita::Handlers::EzOfficeInventory).to receive(:get_assets_by_search).and_return("")
      send_command("ezsearch iPhone 6")
      expect(replies.last).to eq("No devices found matching your query.")
    end

    it 'returns error message if an exception was caught' do
      stub_request(:get, /search/).to_raise(StandardError.new("some exception error"))
      send_command("ezsearch iPhone 6")
      expect(replies.last).to eq("some exception error")
    end
  end
  
  describe '#ez_checkout_asset' do
    location = "local"
    location_id = 12
    asset_id = 24
    asset_name = "device_test"
    email = "teste@anki.com"
    data_error = '{"error":"error cannot checkout.","status":403}'
    data_asset = '{
                  "asset": {
                              "state": "checkout",
                              "sequence_num": 24,
                              "name": "device_test",
                              "assigned_to_user_name": "test_user",
                              "identifier": 111
                            }
                  }'
      user = '{
              "id": 12
              }'

    it 'return ez_checkout_asset.user_not_found message when checking out with user doesnot exist' do
      expected = "User was not found in EzOffice."

      allow_any_instance_of(Lita::Handlers::EzOfficeInventory).\
                            to receive(:find_location_id).and_return(location_id)
      stub_request(:get, /#{asset_id}/).to_return(:status => 200, :body => data_asset)
      allow_any_instance_of(Lita::Handlers::EzOfficeInventory).\
                            to receive(:find_member_by_email).and_return("")
      stub_request(:put, /checkout.api/).to_return(:status => 200, :body => "")
      send_command("ezcheckout #{asset_id} #{email}")
      expect(replies.last).to eq(expected)
    end

    it 'return ez_checkout_asset.location_not_found message when checking out with location doesnot exist' do
      location_id_empty = ""
      expected = "Location *#{location}* was not found in EzOffice."
      
      allow_any_instance_of(Lita::Handlers::EzOfficeInventory).\
                            to receive(:find_location_id).and_return("")
      stub_request(:get, /#{asset_id}/).to_return(:status => 200, :body => data_asset)
      allow_any_instance_of(Lita::Handlers::EzOfficeInventory).\
                            to receive(:find_member_by_email).and_return(user)
      stub_request(:put, /checkout.api/).to_return(:status => 200, :body => "")
      send_command("ezcheckout #{asset_id} #{email} #{location}")
      expect(replies.last).to eq(expected)
    end

    it 'return ez_checkout_asset.asset_checked_out message when checking out with asset was checked out ' do
      expected =  "<#{registry.config.handlers.common.jira.ez_office_site}/#{asset_id}"\
                  "|#{asset_id} - #{asset_name}> is already checked out by *test_user*."
      data_asset_checked_out = '{
                                  "asset": {
                                              "sequence_num": 24,
                                              "name": "device_test",
                                              "assigned_to_user_name": "test_user",
                                              "state": "checked_out"
                                            }
                                }'

      allow_any_instance_of(Lita::Handlers::EzOfficeInventory).\
                            to receive(:find_location_id).and_return(location_id)
      stub_request(:get, /#{asset_id}.api/).to_return(:status => 200, :body => data_asset_checked_out)
      allow_any_instance_of(Lita::Handlers::EzOfficeInventory).\
                            to receive(:find_member_by_email).and_return(user)
      stub_request(:put, /checkout.api/).to_return(:status => 200, :body => "")
      send_command("ezcheckout #{asset_id} #{email} #{location}")
      expect(replies.last).to eq(expected)
    end

    it 'return ez_checkout_asset.asset_not_found message when checking out with asset doesnot exist' do
      expected =  "This device was not found in EzOffice."

      allow_any_instance_of(Lita::Handlers::EzOfficeInventory).\
                            to receive(:find_location_id).and_return(location_id)
      stub_request(:get, /#{asset_id}/).to_return(:status => 200, :body => data_error)
      allow_any_instance_of(Lita::Handlers::EzOfficeInventory).\
                            to receive(:find_member_by_email).and_return(user)
      stub_request(:put, /checkout.api/).to_return(:status => 200, :body => "")
      send_command("ezcheckout #{asset_id} #{email}")
      expect(replies.last).to eq(expected)
    end

    it 'return ez_checkout_asset.checkout_result message when checking out without location' do
      expected =  "Checked out *<#{registry.config.handlers.common.jira.ez_office_site}"\
                  "/#{asset_id}|#{asset_id}"\
                  " - #{asset_name}>* to *test_user*.\n"\
                  "*Asset #:* #{asset_id}\n*Name:* #{asset_name}"\
                  "\n*Asset Identification Number:* 111"\
                  "\n*Email:* #{email}\n*Location:* San Francisco"\
                  "\n*Status:* Checkout"
      allow_any_instance_of(Lita::Handlers::EzOfficeInventory).\
                            to receive(:find_location_id).and_return(location_id)
      stub_request(:get, /#{asset_id}.api/).to_return(:status => 200, :body => data_asset)
      allow_any_instance_of(Lita::Handlers::EzOfficeInventory).\
                            to receive(:find_member_by_email).and_return(user)
      stub_request(:put, /checkout.api/).to_return(:status => 200, :body => "")
      send_command("ezcheckout #{asset_id} #{email}")
      expect(replies.last).to eq(expected)
    end

    it 'return ez_checkout_asset.checkout_result message when when checking out with correct location' do
      expected =  "Checked out *<#{registry.config.handlers.common.jira.ez_office_site}"\
                  "/#{asset_id}|#{asset_id}"\
                  " - #{asset_name}>* to *test_user*.\n"\
                  "*Asset #:* #{asset_id}\n*Name:* #{asset_name}"\
                  "\n*Asset Identification Number:* 111"\
                  "\n*Email:* #{email}\n*Location:* #{location}"\
                  "\n*Status:* Checkout"
      allow_any_instance_of(Lita::Handlers::EzOfficeInventory).\
                            to receive(:find_location_id).and_return(location_id)
      stub_request(:get, /#{asset_id}.api/).to_return(:status => 200, :body => data_asset)
      allow_any_instance_of(Lita::Handlers::EzOfficeInventory).\
                            to receive(:find_member_by_email).and_return(user)
      stub_request(:put, /checkout.api/).to_return(:status => 200, :body => "")
      send_command("ezcheckout #{asset_id} #{email} #{location}")
      expect(replies.last).to eq(expected)
     end
  end
  
  describe '#find_location_id' do

    before do
      locations_json = [{"name"=>"Viet Nam", "sequence_num"=>1}, {"name"=>"Boston", "sequence_num"=>2}]
      allow_any_instance_of(Lita::Handlers::EzOfficeInventory).to receive(:get_data_from_ez).and_return(locations_json)
    end

    it 'return location_id that is found by location_name' do
      location_name = "Viet Nam"
      result = subject.find_location_id(location_name)
      expect(result).to eq(1)
    end

    it 'return empty location_id if no matching location_name in ez office' do
      location_name = "Canada"
      result = subject.find_location_id(location_name)
      expect(result).to eq("")
    end
  end
end
