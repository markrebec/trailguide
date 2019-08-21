require 'rails_helper'

RSpec.describe TrailGuide::Algorithms::Algorithm do
  experiment
  subject { described_class.new(experiment) }

  describe '.choose!' do
    it 'initializes an instance with the experiment' do
      algo = described_class.new(experiment)
      expect(described_class).to receive(:new).with(experiment).and_return(algo)
      allow(algo).to receive(:choose!).with(metadata: {})
      described_class.choose!(experiment, metadata: {})
    end

    it 'calls choose! on the instance' do
      algo = described_class.new(experiment)
      allow(described_class).to receive(:new).with(experiment).and_return(algo)
      expect(algo).to receive(:choose!).with(metadata: {})
      described_class.choose!(experiment, metadata: {})
    end

    it 'raises a NotImplementedError' do
      expect { described_class.choose!(experiment, metadata: {}) }.to raise_exception(NotImplementedError)
    end
  end

  describe '#initialize' do
    it 'memoizes the @experiment' do
      expect(subject.instance_variable_get(:@experiment)).to be(experiment)
    end
  end
end
