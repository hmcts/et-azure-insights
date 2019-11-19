# frozen_string_literal: true

Rails.application.routes.draw do
  mount EtAzureInsights::Engine => '/et_azure_insights'
end
