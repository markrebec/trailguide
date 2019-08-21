require 'rails_helper'

RSpec.describe TrailGuide::Algorithms::Static do
  experiment { |cfg|
    cfg.sticky_assignment = false
    variant :control, metadata: {foo: :bar}
    variant :alternate, metadata: {foo: :baz}
  }
  let(:block) { -> (variable,content) { true } }
  subject { described_class.new(experiment, &block) }

  describe '.choose!' do
    it 'initializes an instance with the experiment' do
      expect(described_class).to receive(:new).with(experiment) { |&blk| expect(blk).to be(block) }.and_return(subject)
      allow(subject).to receive(:choose!).with(metadata: {})
      described_class.choose!(experiment, metadata: {}, &block)
    end

    it 'calls choose! on the instance' do
      allow(described_class).to receive(:new).with(experiment).and_return(subject)
      expect(subject).to receive(:choose!).with(metadata: {})
      described_class.choose!(experiment, metadata: {}, &block)
    end

    it 'returns a valid variant' do
      expect(described_class.choose!(experiment, metadata: {}, &block)).to be_in(experiment.variants)
    end
  end

  describe '#initialize' do
    context 'without an experiment' do
      context 'with a block' do
        subject { described_class.new(&block) }

        it 'memoizes the @block' do
          expect(subject.instance_variable_get(:@block)).to be(block)
        end
      end

      context 'without a block' do
        it 'raises an ArgumentError' do
          expect { described_class.new }.to raise_exception(ArgumentError)
        end
      end
    end

    context 'with an experiment' do
      context 'with a block' do
        it 'memoizes the @experiment' do
          expect(subject.instance_variable_get(:@experiment)).to be(experiment)
        end

        it 'memoizes the @block' do
          expect(subject.instance_variable_get(:@block)).to be(block)
        end
      end

      context 'without a block' do
        it 'raises an ArgumentError' do
          expect { described_class.new(experiment) }.to raise_exception(ArgumentError)
        end
      end
    end
  end

  describe '#new' do
    subject! { described_class.new(&block) }

    it 'initializes a copy of itself with the experiment populated' do
      expect(described_class).to receive(:new).with(experiment) { |&blk| expect(blk).to eq(block) }
      subject.new(experiment)
    end

    context 'when the experiment is configured with sticky assignment' do
      experiment { |cfg| cfg.sticky_assignment = true }

      it 'logs a warning' do
        expect(TrailGuide.logger).to receive(:warn)
        subject.new(experiment)
      end
    end
  end

  describe '#choose!' do
    context 'when the configured block matches a variant' do
      let(:block) { -> (variant,content) { variant[:foo] == content[:foo] } }

      it 'returns the matching variant' do
        expect(subject.choose!(metadata: {foo: :baz})).to eq(:alternate)
      end
    end

    context 'when no metadata is present' do
      it 'does not call the block' do
        expect(block).to_not receive(:call)
      end

      it 'returns control' do
        expect(subject.choose!).to be(experiment.control)
      end
    end

    context 'when metadata is present' do
      it 'calls the block against all variants' do
        expect(block).to receive(:call).twice
        subject.choose!(metadata: {foo: :bar})
      end

      context 'when no variants match the metadata' do
        let(:block) { -> (variable,content) { false } }

        it 'returns control' do
          expect(subject.choose!(metadata: {foo: :bar})).to be(experiment.control)
        end
      end

      context 'when the called block raises an error' do
        let(:block) { -> (variable,content) { raise StandardError, 'Dummy error message' } }

        it 'logs the error' do
          expect(TrailGuide.logger).to receive(:error).with('StandardError: Dummy error message').ordered
          expect(TrailGuide.logger).to receive(:error).with(any_args).ordered
          subject.choose!(metadata: {foo: :bar})
        end

        it 'returns control' do
          expect(subject.choose!).to be(experiment.control)
        end
      end
    end
  end
end
