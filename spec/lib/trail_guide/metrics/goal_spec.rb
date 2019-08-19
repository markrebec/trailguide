require 'rails_helper'

RSpec.describe TrailGuide::Metrics::Goal do
  experiment
  let(:name) { :foo }
  subject { described_class.new(experiment, name) }

  describe '#dup' do
    let(:duplicate) { subject.dup(experiment) }
    let(:other) { subject.dup(create_experiment(:other)) }

    it 'creates a new goal using the class' do
      expect(TrailGuide::Metrics::Goal).to receive(:new).with(experiment, subject.name, any_args)
      subject.dup(experiment)
    end

    it 'creates a new goal with the same properties for the provided experiment' do
      expect(subject === duplicate).to be_truthy
      expect(subject === other).to be_falsey
    end
  end

  describe '#initialize' do
    it 'sets the @experiment' do
      expect(subject.instance_variable_get(:@experiment)).to eq(experiment)
    end

    it 'sets the @name' do
      expect(subject.instance_variable_get(:@name)).to eq(name)
    end

    it 'calls configure with the provided arguments' do
      expect_any_instance_of(described_class).to receive(:configure)
      described_class.new(experiment, name)
    end
  end

  describe '#configuration' do
    it 'returns a configuration object' do
      expect(subject.configuration).to be_a(TrailGuide::Metrics::Config)
    end

    it 'memoizes the configuration object' do
      expect(subject.instance_variable_get(:@configuration)).to be(subject.configuration)
    end
  end

  describe '#configure' do
    let(:arg) { {} }
    let(:blk) { -> (cfg) { } }

    it 'calls configure on the configuration object with the provided arguments' do
      expect(subject.configuration).to receive(:configure).with(arg, &blk)
      subject.configure(arg, &blk)
    end
  end

  describe '#==' do
    context 'when other is a goal object' do
      context 'which is a match' do
        let(:other) { described_class.new(experiment, name) }

        it 'returns true' do
          expect(subject).to eq(other)
        end
      end

      context 'which is not a match' do
        let(:other) { described_class.new(experiment, :bar) }

        it 'returns false' do
          expect(subject).to_not eq(other)
        end
      end
    end

    context 'when other is a string' do
      context 'which is a match' do
        let(:other) { 'foo' }

        it 'returns true' do
          expect(subject).to eq(other)
        end
      end

      context 'which is not a match' do
        let(:other) { 'bar' }

        it 'returns false' do
          expect(subject).to_not eq(other)
        end
      end
    end

    context 'when other is a symbol' do
      context 'which is a match' do
        let(:other) { :foo }

        it 'returns true' do
          expect(subject).to eq(other)
        end
      end

      context 'which is not a match' do
        let(:other) { :bar }

        it 'returns false' do
          expect(subject).to_not eq(other)
        end
      end
    end
  end

  describe '#===' do
    context 'when other is a goal object' do
      context 'which is a match' do
        context 'and belongs to the same experiment' do
          let(:other) { described_class.new(experiment, :foo) }

          it 'returns true' do
            expect(proc { subject === other }.call).to be_truthy
          end
        end

        context 'but belongs to another experiment' do
          let(:other) { described_class.new(create_experiment(:another_test_experiment), :foo) }

          it 'returns false' do
            expect(proc { subject === other }.call).to be_falsey
          end
        end
      end

      context 'which is not a match' do
        let(:other) { described_class.new(experiment, :bar) }

        it 'returns false' do
          expect(proc { subject === other }.call).to be_falsey
        end
      end
    end

    context 'when other is a string' do
      let(:other) { 'foo' }

      it 'returns false' do
        expect(proc { subject === other }.call).to be_falsey
      end
    end

    context 'when other is a symbol' do
      let(:other) { :foo }

      it 'returns false' do
        expect(proc { subject === other }.call).to be_falsey
      end
    end
  end

  describe '#allow_conversion?' do
    participant
    let(:trial) { experiment.new(participant) }
    variant(:control)

    context 'when no callbacks are configured' do
      it 'returns true' do
        expect(subject.allow_conversion?(trial, variant)).to be_truthy
      end
    end

    context 'when callbacks are configured' do
      subject { described_class.new(experiment, name) { |cfg| cfg.allow_conversion = -> (expmt, rslt, mtrc, vrnt, ptcpt, mtdt) { return false } } }

      it 'runs the callbacks' do
        expect(subject).to receive(:run_callbacks).with(:allow_conversion, trial, true, variant, trial.participant, nil)
        subject.allow_conversion?(trial, variant)
      end

      it 'returns the result of the callbacks' do
        expect(subject.allow_conversion?(trial, variant)).to be_falsey
      end
    end
  end

  describe '#run_callbacks' do
    pending
  end

  describe '#to_s' do
    it 'returns the name as a string' do
      expect(subject.to_s).to eq('foo')
    end
  end

  describe '#storage_key' do
    it 'appends the goal name to the experiment name' do
      expect(subject.storage_key).to eq("#{experiment.experiment_name}:foo")
    end
  end
end
