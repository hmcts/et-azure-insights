# frozen_string_literal: true

module EtAzureInsights
  # The feature detector is used to conditionally define code depending on dependency requirements.
  # This is used to enable certain features depending on the environment.
  #
  # For example, if you have sidekiq installed, it will hook into it.  If you don't, the code will not fail
  module FeatureDetector
    @items = {}

    def self.define(&block)
      feature = Feature.new
      feature.instance_eval(&block)
      raise "Feature must be named using the 'name :my_name' syntax" unless feature.named?
      raise "Feature named #{feature.name} already exists" if @items.key?(feature.name)

      @items[feature.name] = feature
    end

    def self.install_all!
      @items.values.each do |feature|
        next unless feature.dependencies_satisfied?

        feature.execute
      end
    end
  end

  # @private
  class Feature
    def initialize
      @dependencies = []
      @run_blocks = []
      self.executed = false
    end

    def name(*args)
      @name = args[0] unless args.empty?
      @name
    end

    def named?
      defined?(@name)
    end

    def dependency(&block)
      @dependencies << block
    end

    def run(&block)
      @run_blocks << block
    end

    def dependencies_satisfied?
      !executed && check_dependencies
    end

    def execute
      @run_blocks.each(&:call)
      self.executed = true
    end

    private

    attr_accessor :executed

    def check_dependencies
      @dependencies.all?(&:call)
    rescue StandardError
      false
    end
  end
end
