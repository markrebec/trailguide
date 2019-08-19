require 'rails_helper'

RSpec.describe TrailGuide::Metrics::Checkpoint do
  experiment
  let(:name) { :foo }
  subject { described_class.new(experiment, name) }

  describe '#initialize' do
    it 'sets the @experiment' do
      expect(subject.instance_variable_get(:@experiment)).to eq(experiment)
    end

    it 'sets the @name' do
      expect(subject.instance_variable_get(:@name)).to eq(name)
    end
  end

  pending 'TODO finish work on implementing checkpoints'
end
