module ModeHelper
  # Issues
  module Email
    def send_email(options = {}, argument_platform, to_email, cc_email, from_email, email_data, period, environment)
      to_email = to_email.split(',')
      cc_email = cc_email.split(',')

      Mail.defaults do
        delivery_method :smtp, options
      end
      if(period == 'day')
        time_period = 'Daily'
      else
        time_period = 'Weekly'
      end
      if(argument_platform == 'overdrive')
        project = 'OverDrive'
      else
        project = 'Cozmo'
      end
      if (environment == 'DEV')
          environment_info = 'DEV/BETA'
      end
      mail = Mail.new do
        to      to_email
        from    "#{from_email}-#{project}@anki.com"
        cc      cc_email
        subject "[#{project} #{environment_info} #{time_period} Report] Top ERRORs from Mode"
        body    ''
      end

      html_part = Mail::Part.new do
        content_type 'text/html; charset=UTF-8'
        body email_data
      end

      mail.html_part = html_part
      mail.delivery_method :sendmail
      mail.deliver
    end
  end
end
