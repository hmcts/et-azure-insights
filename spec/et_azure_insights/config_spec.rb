# frozen_string_literal: true

require 'rails_helper'
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
      it 'writes the value as a string' do
        subject.insights_key = 'randomstring'
        expect(subject.insights_key).to eq 'randomstring'
      end
    end

    describe 'insights_role_name' do
      it 'writes the value as a string' do
        subject.insights_role_name = 'anotherrandomstring'
        expect(subject.insights_role_name).to eq 'anotherrandomstring'
      end
    end

    describe 'insights_role_instance' do
      it 'writes the value as a string' do
        subject.insights_role_instance = 'yetanotherrandomstring'
        expect(subject.insights_role_instance).to eq 'yetanotherrandomstring'
      end
    end
  end
end