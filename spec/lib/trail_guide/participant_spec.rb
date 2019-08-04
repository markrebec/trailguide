require 'rails_helper'

RSpec.describe TrailGuide::Participant do

  describe '#initialize' do
    context 'with an adapter argument' do
      let(:adapter) { TrailGuide::Adapters::Participants::Cookie }
      let(:context) do
        klass = Class.new do
          def cookies
            {}
          end
        end
        klass.new
      end
      subject { described_class.new(context, adapter: adapter) }

      it 'initializes the provided adapter' do
        expect(subject.adapter).to be_an_instance_of(TrailGuide::Adapters::Participants::Cookie::Adapter)
      end
    end

    context 'without an adapter argument' do
      subject { described_class.new(nil) }

      it 'does not initialize an adapter' do
        expect(subject.send(:instance_variable_get, :@adapter)).to be_nil
      end
    end

    context 'when configured to clean up inactive experiments' do
      before { TrailGuide.configuration.cleanup_participant_experiments = true }
      after  { TrailGuide.configuration.cleanup_participant_experiments = false }

      it 'cleans up inactive experiments for the participant' do
        expect_any_instance_of(described_class).to receive(:cleanup_inactive_experiments!)
        described_class.new(nil)
      end
    end
  end

  describe '#adapter' do
    # TODO example for each supported adapter type
  end

  describe '#variant' do
    #context 'when the result has been memoized'
    context 'when the experiment is not calibrating or started' do
      it 'returns nil'
    end

    context 'when the experiment storage key does not exist' do
      it 'returns nil'
    end

    context 'when the stored variant does not exist in the experiment' do
      it 'returns nil'
    end

    context 'when the variant storage key does not exist' do
      it 'returns nil'
    end

    context 'when the experiment is calibrating' do
      context 'and the variant is the control' do
        it 'returns the variant'
      end

      context 'and the variant is not the control' do
        it 'returns nil'
      end
    end

    context 'when the experiment is started' do
      context 'and the variant timestamp is newer than the experiment start timestamp' do
        it 'returns the variant'
      end

      context 'and the variant timestamp is older than the experiment start timestamp' do
        it 'returns nil'
      end
    end
  end

  describe '#participating?' do
    #context 'when the result has been memoized'
    context 'when the variant does not exist' do
      it 'returns false'
    end

    context 'when the include_control argument is true' do
      context 'and the variant is the control' do
        it 'returns true'
      end

      context 'and the variant is not the control' do
        it 'returns true'
      end
    end

    context 'when the include_control argument is false' do
      context 'and the variant is the control' do
        it 'returns false'
      end

      context 'and the variant is not the control' do
        it 'returns true'
      end
    end
  end

  describe '#converted?' do
    context 'when the experiment is not started' do
      context 'and the experiment is not calibrating' do
        it 'returns false'
      end

      context 'and the experiment is calibrating' do
        context 'but the variant is not the control' do
          it 'returns false'
        end
      end
    end

    context 'when the experiment does not have any metrics' do
      #context 'and the result has been memoized'
      context 'and a checkpoint argument was provided' do
        it 'raises an InvalidGoalError'
      end

      context 'and the metric storage key does not exist' do
        it 'returns false'
      end

      context 'and the experiment is not calibrating' do
        context 'and the conversion timestamp is newer than the experiment start timestamp' do
          it 'returns true'
        end

        context 'and the conversion timestamp is older than the experiment start timestamp' do
          it 'returns false'
        end
      end

      context 'and the experiment is calibrating' do
        context 'and the variant is the control' do
          it 'returns true'
        end

        context 'but the variant is not the control' do
          it 'returns false'
        end
      end
    end

    context 'when the experiment does have configured metrics' do
      context 'and a checkpoint argument was provided' do
        #context 'and the result has been memoized'
        context 'but the checkpoint is not a valid metric' do
          it 'raises an InvalidGoalError'
        end

        context 'and the metric storage key does not exist' do
          it 'returns false'
        end

        context 'and the experiment is not calibrating' do
          context 'and the conversion timestamp is newer than the experiment start timestamp' do
            it 'returns true'
          end

          context 'and the conversion timestamp is older than the experiment start timestamp' do
            it 'returns false'
          end
        end

        context 'and the experiment is calibrating' do
          context 'and the variant is the control' do
            it 'returns true'
          end

          context 'but the variant is not the control' do
            it 'returns false'
          end
        end
      end

      context 'and a checkpoint argument was not provided' do
        #context 'and any results have been memoized'
        context 'and the experiment is not calibrating' do
          context 'and any of the conversion timestamps are newer than the experiment start timestamp' do
            it 'returns true'
          end

          context 'and none of the conversion timestamps are newer than the experiment start timestamp' do
            it 'returns false'
          end
        end

        context 'and the experiment is calibrating' do
          context 'and the variant is the control' do
            it 'returns true'
          end

          context 'but the variant is not the control' do
            it 'returns false'
          end
        end
      end
    end
  end

  describe '#participating!' do
    #it 'memoizes the result'
    it 'stores the variant under the experiment storage key'
    it 'stores the timestamp under the variant storage key'
  end

  describe '#converted!' do
    context 'when a checkpoint is provided' do
      it 'uses the metric storage key'
    end

    context 'when no checkpoint is provided' do
      it 'uses a generic storage key'
    end

    context 'when the reset argument is true' do
      it 'deletes the experiment storage key immediately'
      it 'deletes the variant storage key immediately'
      it 'deletes the metric storage key immediately'
      it 'deletes any other metric storage keys immediately'
    end

    context 'when the reset argument is false' do
      it 'stores the conversion timestamp under the storage key'
    end
  end

  describe '#exit!' do
    #it 'deletes any memoized participation'
    #it 'deletes any memoized conversion'
    #it 'deletes any memoized variants'
    context 'when the experiment has not been stored' do
      it 'does not delete any keys'
      it 'returns true'
    end

    it 'deletes the experiment storage key'
    it 'deletes the variant storage key'
    it 'deletes the generic conversion storage key'
    it 'deletes the metric conversion storage keys'
    it 'returns true'
  end

  describe '#active_experiments' do
    context 'when there are no stored experiments' do
      it 'returns false'
    end

    it 'returns a hash of active experiments'
    it 'excludes experiments without sticky assignment'
    it 'excludes combined experiments'
    it 'excludes experiments that are not running'

    context 'when the include_control argument is true' do
      it 'uses the argument when checking participation'
      it 'excludes experiments without valid participation'
    end

    context 'when the include_control argument is false' do
      it 'uses the argument when checking participation'
      it 'excludes experiments without valid participation'
    end

    context 'when configured to cleanup experiments inline' do
      it 'excludes experiments without sticky assignment'

      context 'and there are inactive experiments stored' do
        it 'deletes the stored keys for the inactive experiments'
      end

      context 'but there are no inactive experiments stored' do
        it 'does not delete any stored keys'
      end
    end
  end

  describe '#calibrating_experiments' do
    context 'when there are no stored experiments' do
      it 'returns false'
    end

    it 'returns a hash of calibrating experiments'
    it 'excludes experiments that are not calibrating'
  end

  describe '#participating_in_active_experiments?' do
    context 'when there are no stored experiments' do
      it 'returns false'
    end

    context 'when participating in an active experiment' do
      it 'returns true'
    end

    it 'excludes experiments without sticky assignment'
    it 'excludes combined experiments'
    it 'excludes experiments that are not running'
  end

  describe '#cleanup_inactive_experiments!' do
    context 'when there are no stored experiments' do
      it 'returns false'
    end

    context 'when a stored experiment does not exist' do
      it 'deletes the key'
    end

    context 'when a stored experiment is not started or calibrating' do
      it 'deletes the key'
    end

    context 'when a stored experiment is started' do
      it 'skips the key'
    end

    context 'when a stored experiment is calibrating' do
      it 'skips the key'
    end
  end
end
