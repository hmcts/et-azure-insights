# frozen_string_literal: true

Dir.glob(File.absolute_path('./correlation/**/*.rb', __dir__)).each { |f| require f }
