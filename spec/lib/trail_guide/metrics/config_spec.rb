require 'rails_helper'
require 'shared_examples/config'

RSpec.describe TrailGuide::Metrics::Config do
  experiment {
    goal :foo
  }
  metric(:foo)
  let(:config_hash) { {} }
  subject { described_class.new(metric, **config_hash) }

  describe '#experiment' do
    it 'returns the metric experiment' do
      expect(subject.experiment).to be(experiment)
    end
  end

  describe '#allow_multiple_conversions?' do
    it_behaves_like 'a boolean config method', :allow_multiple_conversions
  end

  describe '#callbacks' do
    it 'returns a hash of callbacks' do
      expect(subject.callbacks).to eq({
        allow_conversion: [],
        on_convert: [],
      })
    end
  end

  describe '#allow_conversion' do
    it_behaves_like 'a callback config method', :allow_conversion
  end

  describe '#on_convert' do
    it_behaves_like 'a callback config method', :on_convert
  end
end
