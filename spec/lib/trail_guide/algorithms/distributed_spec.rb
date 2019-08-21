require 'rails_helper'
require 'shared_examples/algorithm'

RSpec.describe TrailGuide::Algorithms::Distributed do
  experiment
  subject { described_class.new(experiment) }

  it_behaves_like 'an algorithm'

  describe '#choose!' do
    it 'groups variants by participant count' do
      expect(experiment.variants).to receive(:group_by).with(no_args) { |&block| expect(block).to eq(Proc.new &:participants) }.and_return({0 => experiment.variants})
      subject.choose!
    end

    it 'returns results that are statistically evenly distributed' do
      results = 10_000.times.map { subject.choose! }.group_by { |v| v.name }.map { |k,v| [k, v.count] }.to_h
      expect(results[:control]).to be_between(4_500,5_500)
      expect(results[:alternate]).to be_between(4_500,5_500)
      expect(results.values.sum).to eq(10_000)
    end

    it 'returns a valid variant' do
      expect(subject.choose!).to be_in(experiment.variants)
    end
  end
end
