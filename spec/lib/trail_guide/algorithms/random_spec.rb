require 'rails_helper'
require 'shared_examples/algorithm'

RSpec.describe TrailGuide::Algorithms::Random do
  experiment
  subject { described_class.new(experiment) }

  it_behaves_like 'an algorithm'

  describe '#choose!' do
    it 'samples a random variant from the experiment' do
      expect(experiment.variants).to receive(:sample)
      subject.choose!
    end

    it 'returns a valid variant' do
      expect(subject.choose!).to be_in(experiment.variants)
    end
  end
end
