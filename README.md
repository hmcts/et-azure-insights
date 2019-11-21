# EtAzureInsights

This gem is a general purpose rails integration for azure insights.

At the moment (hence its name) it is only for use with the employment tribunals application
but once this has been done it may become more generic and be usable for many apps including outside
of HMCTS - but one step at a time.

## Usage
Using the gem in its most basic form involves adding it to your Gemfile and configuring it - simple as that

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'et_azure_insights'
```

## Configuration

### Rails

To configure in a rails application, add the following to your config/application.rb or config/environments/*.rb

```ruby

    config.azure_insights.enable = true
    config.azure_insights.key = 'yourinsightskey'
    config.azure_insights.role_name = 'microservice-role-name'
    config.azure_insights.role_instance = ENV.fetch('HOSTNAME', 'default-instance-name')
    config.azure_insights.buffer_size = 500
    config.azure_insights.send_interval = 60
```

### Non Rails

This gem can be used in a non rails environment, but you will need to hook things in yourself.

To configure, do :-

```ruby
EtAzureInsights.configure do |c|
  insights_key = ENV.fetch('AZURE_APP_INSIGHTS_KEY', false)
  unless insights_key
    c.enable = false
    next
  end
  c.enable = true
  c.insights_key = insights_key
  c.insights_role_name = ENV.fetch('AZURE_APP_INSIGHTS_ROLE_NAME', 'et-api')
  c.insights_role_instance = ENV.fetch('HOSTNAME', nil)
end

```

This will allow enabling and disabling of it using environment variables.  You can of course
tweak this code to suit your requirements.

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
