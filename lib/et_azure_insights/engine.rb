# frozen_string_literal: true

module EtAzureInsights
  # This class is to allow the rails application to identify this gem as an engine and call
  # initializers etc..
  class Engine < ::Rails::Engine
    isolate_namespace EtAzureInsights
  end
end
