# frozen_string_literal: true

Dir.glob(File.absolute_path('./request_adapter/**/*.rb', __dir__)).each { |f| require f }
