# frozen_string_literal: true

module EtAzureInsights
  # Used to help configure the client for use.
  # Provides help with setting up the context as well as formatting data for the azure service
  module ClientHelper
    def format_request_duration(duration_seconds)
      if duration_seconds >= 86_400
        # just return 1 day when it takes more than 1 day which should not happen for requests.
        return '01.00:00:00.0000000'
      end

      Time.at(duration_seconds).gmtime.strftime('00.%H:%M:%S.%7N')
    end

    def configure_telemetry_context!(operation_id:, operation_parent_id:, operation_name:)
      context = client.context
      setup_operation(context, operation_id: operation_id, operation_parent_id: operation_parent_id, operation_name: operation_name)
      setup_cloud(context)
      context
    end

    def setup_cloud(context)
      context.cloud.role = config.insights_role_name unless config.insights_role_name.nil?
      context.cloud.role_instance = config.insights_role_instance unless config.insights_role_instance.nil?
    end

    def setup_operation(context, operation_id:, operation_parent_id:, operation_name:)
      context.operation.id = operation_id
      context.operation.parent_id = operation_parent_id
      context.operation.name = operation_name
    end
  end
end
