# frozen_string_literal: true

Dir.glob(File.absolute_path('./instrumentors/**/*.rb', __dir__)).each { |f| require f }
