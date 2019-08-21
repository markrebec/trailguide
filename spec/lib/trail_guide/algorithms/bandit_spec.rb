require 'rails_helper'
require 'shared_examples/algorithm'

RSpec.describe TrailGuide::Algorithms::Bandit do
  experiment {
    variant :control
    variant :alternate
    variant :other
    variant :another
  }
  variant(:control)
  variant(:alternate)
  variant(:other)
  variant(:another)
  subject { described_class.new(experiment) }

  it_behaves_like 'an algorithm'

  describe '#choose!' do
    it 'returns a valid variant' do
      expect(subject.choose!).to be_in(experiment.variants)
    end

    it 'returns results consistent with the winning variant with periodic sampling of others' do
      allow(control).to receive(:participants).and_return(800)
      allow(control).to receive(:converted).and_return(400)
      allow(alternate).to receive(:participants).and_return(100)
      allow(alternate).to receive(:converted).and_return(20)
      allow(other).to receive(:participants).and_return(50)
      allow(other).to receive(:converted).and_return(5)
      allow(another).to receive(:participants).and_return(30)
      allow(another).to receive(:converted).and_return(1)

      results = 10_000.times.map { described_class.new(experiment).choose! }.group_by { |v| v.name }.map { |k,v| [k, v.count] }.to_h
      expect(results[:control]).to be >= 9900
      expect(results.slice(:alternate, :other, :another).values.sum).to be <= 100
      expect(results.values.sum).to eq(10_000)
    end
  end
end
