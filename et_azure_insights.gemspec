# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'et_azure_insights/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'et_azure_insights'
  spec.version     = EtAzureInsights::VERSION
  spec.authors     = ['Gary Taylor']
  spec.email       = ['gary.taylor@hismessages.com']
  spec.homepage    = 'https://github.com/hmcts/et-azure-insights'
  spec.summary     = 'Azure application insights'
  spec.description = 'A rails gem (written for rails 6) for employment tribunals microservices that integrates into microsoft application insights'
  spec.license     = 'MIT'

  spec.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']

  spec.metadata['yard.run'] = 'yri' # use "yard" to build full HTML docs.

  spec.add_dependency 'application_insights', '~> 0.5.7' # Note, 0.5.7 is not released at this point so the Gemfile of the application

  spec.add_development_dependency 'activejob', '~> 6.0', '>= 6.0.2.1'
  spec.add_development_dependency 'activesupport', '~> 6.0', '>= 6.0.1'
  spec.add_development_dependency 'activerecord', '~> 6.0', '>= 6.0.2.1'
  spec.add_development_dependency 'rack', '~> 2.0', '>= 2.0.7'
  spec.add_development_dependency 'random-port', '~> 0.5.1'
  spec.add_development_dependency 'redis', '~> 5.0'
  spec.add_development_dependency 'rspec', '~> 3.9'
  spec.add_development_dependency 'rspec-eventually', '~> 0.2.2'
  spec.add_development_dependency 'rubocop', '~> 0.76.0'
  spec.add_development_dependency 'sqlite3', '~> 1.4', '>= 1.4.2'
  spec.add_development_dependency 'sidekiq', '~> 7.0'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'excon', '~> 0.72.0'
  spec.add_development_dependency 'typhoeus', '~> 1.3', '>= 1.3.1'
  spec.add_development_dependency 'webmock', '~> 3.7', '>= 3.7.6'
  spec.add_development_dependency 'yard', '~> 0.9.20'
end
