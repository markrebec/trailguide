require 'rails_helper'

RSpec.describe TrailGuide::Variants do
  experiment
  variant(:control)
  variant(:alternate)
  subject { described_class.new(experiment.variants.to_a) }

  describe '#dup' do
    experiment(:other)

    it 'duplicates each variant for the provided experiment' do
      subject.each { |var| expect(var).to receive(:dup).with(other).and_call_original }
      subject.dup(other)
    end

    it 'returns a new collection' do
      expect(subject.dup(other)).to be_a(described_class)
      expect(subject.dup(other).to_a).to contain_exactly(*subject.to_a)
    end
  end

  describe '#control' do
    context 'when a control variant exists' do
      it 'returns the control variant' do
        expect(subject.control).to be(control)
      end
    end

    context 'when no control variant exists' do
      subject { described_class.new }

      it 'returns nil' do
        expect(subject.control).to be_nil
      end
    end
  end

  describe '#method_missing' do
    context 'when the called method matches a variant in the list' do
      it 'returns the variant' do
        expect(subject.alternate).to be(alternate)
      end
    end

    context 'when the array of variants responds to the called method' do
      it 'calls the method on the array' do
        expect(subject.variants).to receive(:select)
        subject.select { |v| true }
      end

      context 'and the result of the called method is an array' do
        it 'returns a new collection' do
          expect(subject.select { |v| true }).to be_a(described_class)
        end
      end
    end
  end
end
