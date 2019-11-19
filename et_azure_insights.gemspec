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

  spec.add_dependency 'application_insights', '~> 0.5.6'

  spec.add_development_dependency 'pg'
  spec.add_development_dependency 'rails', '~> 6.0.1'
  spec.add_development_dependency 'rspec-rails', '~> 3.9'
  spec.add_development_dependency 'rubocop', '~> 0.76.0'
  spec.add_development_dependency 'yard', '~> 0.9.20'
end
