# frozen_string_literal: true

require 'spec_helper'
require 'et_azure_insights/config'
RSpec.describe EtAzureInsights::Config do
  context 'class methods' do
    let(:subject) { described_class }
    describe '#configure' do
      it 'yields the instance to the block' do
        subject.configure do |instance|
          expect(instance).to be_a described_class
        end
      end

      it 'returns the instance when no block given' do
        result = subject.configure
        expect(result).to be_a described_class
      end
    end

    describe '#config' do
      it 'returns the instance' do
        result = subject.configure
        expect(result).to be_a described_class
      end
    end
  end

  context 'instance methods' do
    let(:subject) { described_class.configure }
    around do |example|
      old = EtAzureInsights::Config.config.enable
      example.run
      EtAzureInsights::Config.config.enable = old
    end

    describe '#enable=' do
      it 'writes the value as true' do
        subject.enable = true
        expect(subject.enable).to be true
      end

      it 'writes the value as false' do
        subject.enable = false
        expect(subject.enable).to be false
      end
    end

    describe '#insights_key=' do
      around do |example|
        old = EtAzureInsights::Config.config.insights_key
        example.run
        EtAzureInsights::Config.config.insights_key = old
      end

      it 'writes the value as a string' do
        subject.insights_key = 'randomstring'
        expect(subject.insights_key).to eq 'randomstring'
      end
    end

    describe 'insights_role_name' do
      around do |example|
        old = EtAzureInsights::Config.config.insights_role_name
        example.run
        EtAzureInsights::Config.config.insights_role_name = old
      end


      it 'writes the value as a string' do
        subject.insights_role_name = 'anotherrandomstring'
        expect(subject.insights_role_name).to eq 'anotherrandomstring'
      end
    end

    describe 'insights_role_instance' do
      around do |example|
        old = EtAzureInsights::Config.config.insights_role_instance
        example.run
        EtAzureInsights::Config.config.insights_role_instance = old
      end

      it 'writes the value as a string' do
        subject.insights_role_instance = 'yetanotherrandomstring'
        expect(subject.insights_role_instance).to eq 'yetanotherrandomstring'
      end
    end

    describe 'buffer_size=' do
      around do |example|
        old = EtAzureInsights::Config.config.buffer_size
        example.run
        EtAzureInsights::Config.config.buffer_size = old
      end

      it 'writes the value as an integer' do
        subject.buffer_size = 19
        expect(subject.buffer_size).to eq 19
      end
    end

    describe 'send_interval=' do
      around do |example|
        old = EtAzureInsights::Config.config.buffer_size
        example.run
        EtAzureInsights::Config.config.buffer_size = old
      end

      it 'writes the value as a float' do
        subject.buffer_size = 21.5
        expect(subject.buffer_size).to eq 21.5
      end
    end

    describe 'logger=' do
      around do |example|
        old = EtAzureInsights::Config.config.logger
        example.run
        EtAzureInsights::Config.config.logger = old
      end

      it 'stores the object' do
        fake_object = Object.new
        subject.logger = fake_object
        expect(subject.logger).to be fake_object
      end
    end
  end
end
