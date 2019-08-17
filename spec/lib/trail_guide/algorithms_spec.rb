require 'rails_helper'

RSpec.describe TrailGuide::Algorithms do
  subject { described_class }

  describe '.algorithm' do
    context 'with the :weighted algo' do
      it 'returns the weighted algo' do
        expect(subject.algorithm(:weighted)).to eq(TrailGuide::Algorithms::Weighted)
      end
    end

    context 'with the :bandit algo' do
      it 'returns the bandit algo' do
        expect(subject.algorithm(:bandit)).to eq(TrailGuide::Algorithms::Bandit)
      end
    end

    context 'with the :distributed algo' do
      it 'returns the distributed algo' do
        expect(subject.algorithm(:distributed)).to eq(TrailGuide::Algorithms::Distributed)
      end
    end

    context 'with the :random algo' do
      it 'returns the random algo' do
        expect(subject.algorithm(:random)).to eq(TrailGuide::Algorithms::Random)
      end
    end

    context 'with a custom algo' do
      before {
        Object.send(:remove_const, :CustomAlgoTest) if defined?(CustomAlgoTest)
        CustomAlgoTest = Class.new
      }

      it 'returns the custom algo' do
        expect(subject.algorithm('CustomAlgoTest')).to eq(CustomAlgoTest)
      end
    end
  end
end
