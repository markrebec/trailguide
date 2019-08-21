RSpec.shared_examples 'an algorithm' do
  describe '.choose!' do
    it 'initializes an instance with the experiment' do
      expect(described_class).to receive(:new).with(experiment).and_call_original
      described_class.choose!(experiment, metadata: {})
    end

    it 'calls choose! on the instance' do
      expect_any_instance_of(described_class).to receive(:choose!).with(metadata: {})
      described_class.choose!(experiment, metadata: {})
    end

    it 'returns a valid variant' do
      expect(described_class.choose!(experiment, metadata: {})).to be_in(experiment.variants)
    end
  end

  describe '#initialize' do
    it 'memoizes the @experiment' do
      expect(subject.instance_variable_get(:@experiment)).to be(experiment)
    end
  end
end
