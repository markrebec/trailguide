require 'rails_helper'
require 'shared_examples/algorithm'

RSpec.describe TrailGuide::Algorithms::Weighted do
  experiment {
    variant :control,   weight: 2
    variant :alternate, weight: 1
    variant :other,     weight: 1
  }
  subject { described_class.new(experiment) }

  it_behaves_like 'an algorithm'

  describe '#choose!' do
    it 'returns a valid variant' do
      expect(subject.choose!).to be_in(experiment.variants)
    end

    it 'returns results that are statistically consistent with assigned weights' do
      results = 10_000.times.map { subject.choose! }.group_by { |v| v.name }.map { |k,v| [k, v.count] }.to_h
      expect(results[:control]).to be_between(4_500,5_500)
      expect(results[:alternate]).to be_between(2_250,2_750)
      expect(results[:other]).to be_between(2_250,2_750)
      expect(results.values.sum).to eq(10_000)
    end
  end
end
