require 'rails_helper'

RSpec.describe TrailGuide::Experiments::Participant do
  trial
  subject { trial.participant }

  describe '#initialize' do
    it 'sets the @experiment' do
      expect(subject.instance_variable_get(:@experiment)).to eq(trial)
    end

    it 'sets the @participant' do
      expect(subject.instance_variable_get(:@participant)).to eq(participant)
    end
  end

  describe '#participating?' do
    context 'when a variant is present' do
      before { allow(subject).to receive(:variant).and_return(experiment.control) }

      it 'returns true' do
        expect(subject.participating?).to be_truthy
      end
    end

    context 'when a variant is not present' do
      before { allow(subject).to receive(:variant).and_return(nil) }

      it 'returns false' do
        expect(subject.participating?).to be_falsey
      end
    end
  end

  describe '#participating!' do
    variant(:control)

    it 'sets @participating to true' do
      expect { subject.participating!(variant) }.to change { subject.instance_variable_get(:@participating) }.to(true)
    end

    it 'sets the @variant' do
      expect { subject.participating!(variant) }.to change { subject.instance_variable_get(:@variant) }.to(variant)
    end

    context 'when the experiment is configured with sticky_assignment' do
      it 'calls participating! on the participant with the variant' do
        expect(subject.participant).to receive(:participating!).with(variant)
        subject.participating!(variant)
      end
    end

    context 'when the experiment is not configured with sticky_assignment' do
      trial { |cfg| cfg.sticky_assignment = false }

      it 'does not call participating! on the participant' do
        expect(subject.participant).to_not receive(:participating!)
        subject.participating!(variant)
      end
    end
  end

  describe '#converted?' do
    context 'when @converted is not set' do
      it 'sets the @converted hash' do
        expect { subject.converted? }.to change { subject.instance_variable_get(:@converted) }.from(nil).to({converted: false})
      end
    end

    context 'when @converted is set' do
      before { subject.instance_variable_set(:@converted, {foo: true}) }

      it 'does not override @converted' do
        expect { subject.converted? }.to change { subject.instance_variable_get(:@converted) }.from({foo: true}).to({foo: true, converted: false})
      end
    end

    context 'without a checkpoint' do
      it 'sets the :converted key' do
        expect { subject.converted? }.to change { subject.instance_variable_get(:@converted) }.from(nil).to({converted: false})
      end

      context 'when the key does not exist' do
        it 'calls participant.converted? with the nil checkpoint' do
          expect(subject.participant).to receive(:converted?).with(experiment, nil)
          subject.converted?
        end
      end

      context 'when the key already exists' do
        before { subject.instance_variable_set(:@converted, {converted: false}) }

        it 'does not call participant.converted?' do
          expect(subject.participant).to_not receive(:converted?)
          subject.converted?
        end
      end
    end

    context 'with a checkpoint' do
      it 'sets the checkpoint key' do
        expect { subject.converted?(:test_goal) }.to change { subject.instance_variable_get(:@converted) }.from(nil).to({test_goal: false})
      end

      context 'when the key does not exist' do
        it 'calls participant.converted? with the checkpoint' do
          expect(subject.participant).to receive(:converted?).with(experiment, :test_goal)
          subject.converted?(:test_goal)
        end
      end

      context 'when the key already exists' do
        before { subject.instance_variable_set(:@converted, {test_goal: false}) }

        it 'does not call participant.converted?' do
          expect(subject.participant).to_not receive(:converted?)
          subject.converted?(:test_goal)
        end
      end
    end
  end

  describe '#converted!' do
    variant(:control)

    it 'calls participant.converted! with the variant, checkpoint and reset' do
      expect(subject.participant).to receive(:converted!).with(variant, nil, reset: false)
      subject.converted!(variant, nil, reset: false)
    end

    context 'when @converted is not set' do
      it 'sets the @converted hash' do
        expect { subject.converted!(variant, nil) }.to change { subject.instance_variable_get(:@converted) }.from(nil).to({converted: true})
      end
    end

    context 'when @converted is set' do
      before { subject.instance_variable_set(:@converted, {foo: true}) }

      it 'does not override @converted' do
        expect { subject.converted!(variant, nil) }.to change { subject.instance_variable_get(:@converted) }.from({foo: true}).to({foo: true, converted: true})
      end
    end

    context 'with a checkpoint' do
      before { allow(subject.participant).to receive(:converted!).with(any_args).and_return(true) }

      it 'sets the checkpoint key' do
        expect { subject.converted!(variant, :test_goal) }.to change { subject.instance_variable_get(:@converted) }.from(nil).to({test_goal: true})
      end
    end

    context 'without a checkpoint' do
      it 'sets the :converted key' do
        expect { subject.converted!(variant, nil) }.to change { subject.instance_variable_get(:@converted) }.from(nil).to({converted: true})
      end
    end
  end

  describe '#variant' do
    variant(:control)

    context 'if the @variant already exists' do
      before { subject.instance_variable_set(:@variant, variant) }

      it 'does not call participant.variant' do
        expect(subject.participant).to_not receive(:variant)
        subject.variant
      end
    end

    context 'if the @variant does not exist' do
      it 'calls participant.variant' do
        expect(subject.participant).to receive(:variant).with(experiment)
        subject.variant
      end
    end
  end

  describe '#exit!' do
    variant(:control)

    it 'clears @participating' do
      subject.instance_variable_set(:@participating, true)
      expect { subject.exit! }.to change { subject.instance_variable_get(:@participating) }.from(true).to(nil)
    end

    it 'clears @converted' do
      subject.instance_variable_set(:@converted, {})
      expect { subject.exit! }.to change { subject.instance_variable_get(:@converted) }.from({}).to(nil)
    end

    it 'clears @variant' do
      subject.instance_variable_set(:@variant, variant)
      expect { subject.exit! }.to change { subject.instance_variable_get(:@variant) }.from(variant).to(nil)
    end

    it 'calls participant.exit!' do
      expect(subject.participant).to receive(:exit!)
      subject.exit!
    end
  end

  describe '#method_missing' do
    context 'when the participant responds to the method' do
      it 'calls the method on the participant' do
        expect(subject.participant).to receive(:active_experiments)
        subject.active_experiments
      end

      it 'passes the arguments to the called method' do
        expect(subject.participant).to receive(:active_experiments).with(false)
        subject.active_experiments(false)
      end
    end

    context 'when the participant does not respond to the method' do
      it 'raises a NoMethodError' do
        expect { subject.foobar }.to raise_exception(NoMethodError)
      end
    end
  end

  describe '#respond_to_missing?' do
    context 'when the participant responds to the method' do
      it 'returns true' do
        expect(subject.respond_to?(:active_experiments)).to be_truthy
      end
    end

    context 'when the participant does not respond to the method' do
      it 'returns false' do
        expect(subject.respond_to?(:foobar)).to be_falsey
      end
    end

    context 'when include_private is true' do
      it 'passes include_private when checking participant response' do
        expect(subject.participant).to receive(:respond_to?).with(:foobar, true)
        subject.respond_to?(:foobar, true)
      end
    end
  end
end
