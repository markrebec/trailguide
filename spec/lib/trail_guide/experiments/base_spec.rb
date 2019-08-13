require 'rails_helper'

# TODO should probably use timecop for some of the lifecycle stuff (started_at, paused_at, etc.)

RSpec.describe TrailGuide::Experiments::Base do

  describe 'configuration' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :config_test
          variant :control
          variant :alternate
        end
      end
    }

    it 'returns the configuration object for the experiment' do
      expect(subject.configuration).to be_an_instance_of(TrailGuide::Experiments::Config)
    end

    it 'memoizes the configuration object' do
      expect(subject.instance_variable_get(:@configuration)).to eq(subject.configuration)
    end

    [
      :algorithm,
      :allow_multiple_conversions?,
      :allow_multiple_goals?,
      :callbacks,
      :combined,
      :combined?,
      :control,
      :enable_calibration?,
      :goals,
      :groups,
      :reset_manually?,
      :start_manually?,
      :track_winner_conversions?
    ].each do |method|
      it "delegates ##{method} to the configuration object" do
        expect(subject.configuration).to receive(method)
        subject.send(method)
      end
    end
  end

  describe 'configure' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :configure_test
          variant :control
          variant :alternate
        end
      end
    }

    it 'delegates to the configuration object' do
      expect(subject.configuration).to receive(:configure)
      subject.configure
    end

    it 'passes arguments through when delegating' do
      expect(subject.configuration).to receive(:configure).with({name: 'config_test'})
      subject.configure({name: 'config_test'})
    end
  end

  describe 'experiment_name' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :name_test
          variant :control
          variant :alternate
        end
      end
    }

    it 'returns the experiment name' do
      expect(subject.experiment_name).to eq(:name_test)
    end

    it 'delegates to the configuration object' do
      expect(subject.configuration).to receive(:name)
      subject.experiment_name
    end
  end

  describe 'register!' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :register_test
          variant :control
          variant :alternate
        end
      end
    }

    it 'registers the experiment with the catalog' do
      expect(TrailGuide.catalog).to receive(:register).with(subject)
      subject.register!
    end
  end

  describe 'variants' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :register_test
          variant :control
          variant :alternate
        end
      end
    }

    it 'delegates to the configuration object' do
      expect(subject.configuration).to receive(:variants)
      subject.variants
    end

    context 'when include_control is true' do
      let(:variants) { subject.variants }

      it 'returns an array of all experiment variants' do
        expect(variants.length).to eq(2)
        variants.each { |var| expect(var).to be_an_instance_of(TrailGuide::Variant) }
      end
    end

    context 'when include_control is false' do
      let(:variants) { subject.variants(false) }

      it 'excludes the control variant' do
        expect(variants.length).to eq(1)
        variants.each { |var| expect(var.control?).to be_falsey }
      end
    end
  end

  describe 'is_combined?' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :combined_test
          variant :control
          variant :alternate
        end
      end
    }

    it 'returns false' do
      expect(subject.is_combined?).to be_falsey
    end
  end

  describe 'combined_experiments' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :combined_test
          variant :control
          variant :alternate
        end
      end
    }

    it 'fetches from the configuration object' do
      expect(subject.configuration).to receive(:combined).and_return([])
      subject.combined_experiments
    end

    context 'when not configured with combined experiments' do
      it 'returns an empty array' do
        expect(subject.combined_experiments).to be_empty
      end
    end

    context 'when configured with combined experiments' do
      subject {
        Class.new(described_class) do
          configure do |config|
            config.name = :combined_test
            variant :control
            variant :alternate
            config.combined = [:first_combo, :second_combo]
          end

          register!
        end
      }

      it 'returns an array of the combined experiments' do
        expect(subject.combined_experiments.length).to eq(2)
        subject.combined_experiments.each { |ce| expect(ce).to be < TrailGuide::CombinedExperiment }
      end
    end
  end

  describe 'run_callbacks' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :callback_test
          variant :control
          variant :alternate
        end
      end
    }

    context 'when the hook is not a defined hook' do
      it 'returns nil' do
        expect(subject.run_callbacks(:dummy_hook)).to be_nil
      end
    end

    context 'when no callbacks are defined for the hook' do
      it 'returns an empty array' do
        expect(subject.run_callbacks(:on_start)).to eq([])
      end
    end

    context 'when callbacks are defined for the hook' do
      let(:ctx) { {foo: :bar} }
      let(:start_hook) { -> (exp,ctx) { nil } }
      subject {
        subject_hook = start_hook
        Class.new(described_class) do
          configure do |config|
            config.name = :callback_test
            variant :control
            variant :alternate
            config.on_start = subject_hook
          end
        end
      }

      it 'executes the callback block' do
        expect(start_hook).to receive(:call).with(subject, ctx)
        subject.run_callbacks(:on_start, ctx)
      end

      context 'when the callbacks are defined as method symbols' do
        subject {
          Class.new(described_class) do
            configure do |config|
              config.name = :callback_test
              variant :control
              variant :alternate
              config.on_start = :on_start_callback
            end

            def self.on_start_callback(exp,ctx)
              nil
            end
          end
        }

        it 'calls the method on the experiment' do
          expect(subject).to receive(:on_start_callback).with(subject, ctx)
          subject.run_callbacks(:on_start, ctx)
        end
      end
    end
  end

  describe 'start!' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :start_test
          variant :control
          variant :alternate
        end
      end
    }

    context 'when the experiment is already started' do
      before { subject.start! }

      it 'returns false' do
        expect(subject.start!).to be_falsey
      end

      it 'does not persist the experiment' do
        expect(subject).to_not receive(:save!)
        subject.start!
      end

      it 'does not set the storage key' do
        expect(TrailGuide.redis).to_not receive(:hset)
        subject.start!
      end

      it 'does not fire callbacks' do
        expect(subject).to_not receive(:run_callbacks)
        subject.start!
      end
    end

    context 'when the experiment is not started' do
      it 'returns true' do
        expect(subject.start!).to be_truthy
      end

      it 'persists the experiment' do
        expect(subject).to receive(:save!)
        subject.start!
      end

      it 'sets the storage key' do
        expect(TrailGuide.redis).to receive(:hset).with(subject.storage_key, 'started_at', kind_of(Numeric))
        subject.start!
      end

      it 'runs callbacks' do
        expect(subject).to receive(:run_callbacks).with(:on_start, nil)
        subject.start!
      end

      context 'with a passed in context' do
        let(:ctx) { {foo: :bar} }

        it 'passes the context to callbacks' do
          expect(subject).to receive(:run_callbacks).with(:on_start, ctx)
          subject.start!(ctx)
        end
      end
    end
  end

  describe 'schedule!' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :schedule_test
          variant :control
          variant :alternate
        end
      end
    }
    let(:start_time) { Time.now + 1.hour }

    context 'when the experiment is already running' do
      before { subject.start! }

      it 'returns false' do
        expect(subject.schedule!(start_time)).to be_falsey
      end

      it 'does not persist the experiment' do
        expect(subject).to_not receive(:save!)
        subject.schedule!(start_time)
      end

      it 'does not set the storage key' do
        expect(TrailGuide.redis).to_not receive(:hset)
        subject.schedule!(start_time)
      end

      it 'does not fire callbacks' do
        expect(subject).to_not receive(:run_callbacks)
        subject.schedule!(start_time)
      end
    end

    context 'when the experiment has not been started' do
      it 'returns true' do
        expect(subject.schedule!(start_time)).to be_truthy
      end

      it 'persists the experiment' do
        expect(subject).to receive(:save!)
        subject.schedule!(start_time)
      end

      it 'sets the storage key' do
        expect(TrailGuide.redis).to receive(:hset).with(subject.storage_key, 'started_at', start_time.to_i)
        subject.schedule!(start_time)
      end

      it 'runs callbacks' do
        expect(subject).to receive(:run_callbacks).with(:on_schedule, start_time, nil, nil)
        subject.schedule!(start_time)
      end

      context 'with a stop_at argument' do
        let(:stop_time) { Time.now + 2.hours }

        it 'sets the stop_at storage key' do
          expect(TrailGuide.redis).to receive(:hset).with(subject.storage_key, 'started_at', start_time.to_i)
          expect(TrailGuide.redis).to receive(:hset).with(subject.storage_key, 'stopped_at', stop_time.to_i)
          subject.schedule!(start_time, stop_time)
        end

        it 'passes the stop time to callbacks' do
          expect(subject).to receive(:run_callbacks).with(:on_schedule, start_time, stop_time, nil)
          subject.schedule!(start_time, stop_time)
        end
      end

      context 'with a passed in context' do
        let(:ctx) { {foo: :bar} }

        it 'passes the context to callbacks' do
          expect(subject).to receive(:run_callbacks).with(:on_schedule, start_time, nil, ctx)
          subject.schedule!(start_time, nil, ctx)
        end
      end
    end
  end

  describe 'pause!' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :pause_test
          config.can_resume = true
          variant :control
          variant :alternate
        end
      end
    }

    context 'when the experiment is not running' do
      it 'returns false' do
        expect(subject.pause!).to be_falsey
      end

      it 'does not set the storage key' do
        expect(TrailGuide.redis).to_not receive(:hset)
        subject.pause!
      end

      it 'does not fire callbacks' do
        expect(subject).to_not receive(:run_callbacks)
        subject.pause!
      end
    end

    context 'when the experiment is running' do
      before { subject.start! }

      it 'returns true' do
        expect(subject.pause!).to be_truthy
      end

      it 'sets the storage key' do
        expect(TrailGuide.redis).to receive(:hset).with(subject.storage_key, 'paused_at', kind_of(Numeric))
        subject.pause!
      end

      it 'runs callbacks' do
        expect(subject).to receive(:run_callbacks).with(:on_pause, nil)
        subject.pause!
      end

      context 'with a passed in context' do
        let(:ctx) { {foo: :bar} }

        it 'passes the context to callbacks' do
          expect(subject).to receive(:run_callbacks).with(:on_pause, ctx)
          subject.pause!(ctx)
        end
      end
    end

    context 'when the experiment is not configured as resumable' do
      subject {
        Class.new(described_class) do
          configure do |config|
            config.name = :pause_test
            config.can_resume = false
            variant :control
            variant :alternate
          end
        end
      }

      before { subject.start! }

      it 'returns false' do
        expect(subject.pause!).to be_falsey
      end

      it 'does not set the storage key' do
        expect(TrailGuide.redis).to_not receive(:hset)
        subject.pause!
      end

      it 'does not fire callbacks' do
        expect(subject).to_not receive(:run_callbacks)
        subject.pause!
      end
    end
  end

  describe 'resume!' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :resume_test
          config.can_resume = true
          variant :control
          variant :alternate
        end
      end
    }

    context 'when the experiment is paused' do
      before { subject.start! && subject.pause! }

      it 'returns true' do
        expect(subject.resume!).to be_truthy
      end

      it 'deletes the paused_at storage key' do
        expect(TrailGuide.redis).to receive(:hdel).with(subject.storage_key, 'paused_at')
        subject.resume!
      end

      it 'runs callbacks' do
        expect(subject).to receive(:run_callbacks).with(:on_resume, nil)
        subject.resume!
      end

      context 'with a passed in context' do
        let(:ctx) { {foo: :bar} }
        it 'passes the context to callbacks' do
          expect(subject).to receive(:run_callbacks).with(:on_resume, ctx)
          subject.resume!(ctx)
        end
      end
    end

    context 'when the experiment is not paused' do
      it 'returns false' do
        expect(subject.resume!).to be_falsey
      end

      it 'does not delete the paused_at storage key' do
        expect(TrailGuide.redis).to_not receive(:hdel)
        subject.resume!
      end

      it 'does not fire callbacks' do
        expect(subject).to_not receive(:run_callbacks)
        subject.resume!
      end
    end
  end

  describe 'stop!' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :stop_test
          variant :control
          variant :alternate
        end
      end
    }

    context 'when the experiment has not been started' do
      it 'returns false' do
        expect(subject.stop!).to be_falsey
      end

      it 'does not set the storage key' do
        expect(TrailGuide.redis).to_not receive(:hset)
        subject.stop!
      end

      it 'does not trigger callbacks' do
        expect(subject).to_not receive(:run_callbacks)
        subject.stop!
      end
    end

    context 'when the experiment has already been stopped' do
      before { subject.start! && subject.stop! }

      it 'returns false' do
        expect(subject.stop!).to be_falsey
      end

      it 'does not set the storage key' do
        expect(TrailGuide.redis).to_not receive(:hset)
        subject.stop!
      end

      it 'does not trigger callbacks' do
        expect(subject).to_not receive(:run_callbacks)
        subject.stop!
      end
    end

    context 'when the experiment is started and not stopped' do
      before { subject.start! }

      it 'returns true' do
        expect(subject.stop!).to be_truthy
      end

      it 'sets the stopped_at storage key' do
        expect(TrailGuide.redis).to receive(:hset).with(subject.storage_key, 'stopped_at', kind_of(Numeric))
        subject.stop!
      end

      it 'runs callbacks' do
        expect(subject).to receive(:run_callbacks).with(:on_stop, nil)
        subject.stop!
      end

      context 'with a passed in context' do
        let(:ctx) { {foo: :bar} }

        it 'passes the context to callbacks' do
          expect(subject).to receive(:run_callbacks).with(:on_stop, ctx)
          subject.stop!(ctx)
        end
      end
    end
  end

  describe 'started_at' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :start_test
          variant :control
          variant :alternate
        end
      end
    }

    context 'when the experiment has been scheduled' do
      let(:start_time) { Time.now + 1.hour }
      before { subject.schedule!(start_time) }

      it 'returns the scheduled start time' do
        expect(subject.started_at.to_i).to eq(start_time.to_i)
      end
    end

    context 'when the experiment has been started' do
      before { subject.start! }

      it 'returns the started_at time' do
        expect(subject.started_at).to be_a(Time)
      end

      context 'and then stopped' do
        before { subject.stop! }

        it 'returns the started_at time' do
          expect(subject.started_at).to be_a(Time)
        end
      end
    end

    context 'when the experiment has not been started' do
      it 'returns nil' do
        expect(subject.started_at).to be_nil
      end
    end
  end

  describe 'paused_at' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :pause_test
          config.can_resume = true
          variant :control
          variant :alternate
        end
      end
    }

    context 'when the experiment has been scheduled' do
      before { subject.schedule!(Time.now + 1.hour) }

      it 'returns nil' do
        expect(subject.paused_at).to be_nil
      end
    end

    context 'when the experiment has been started' do
      before { subject.start! }

      it 'returns nil' do
        expect(subject.paused_at).to be_nil
      end

      context 'and has been paused' do
        before { subject.pause! }

        it 'returns the paused_at time' do
          expect(subject.paused_at).to be_a(Time)
        end
      end
    end

    context 'when the experiment has not been started' do
      it 'returns nil' do
        expect(subject.paused_at).to be_nil
      end
    end
  end

  describe 'stopped_at' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :stop_test
          variant :control
          variant :alternate
        end
      end
    }

    context 'when the experiment has been scheduled' do
      before { subject.schedule!(Time.now + 1.hour) }

      it 'returns nil' do
        expect(subject.stopped_at).to be_nil
      end

      context 'with a stop_at time' do
        let(:stop_time) { Time.now + 2.hours }
        before { subject.schedule!(Time.now + 1.hour, stop_time) }

        it 'returns the future stop time' do
          expect(subject.stopped_at.to_i).to eq(stop_time.to_i)
        end
      end
    end

    context 'when the experiment has been started' do
      before { subject.start! }

      it 'returns nil' do
        expect(subject.stopped_at).to be_nil
      end

      context 'and has been stopped' do
        before { subject.stop! }

        it 'returns the paused_at time' do
          expect(subject.stopped_at).to be_a(Time)
        end
      end
    end

    context 'when the experiment has not been started' do
      it 'returns nil' do
        expect(subject.stopped_at).to be_nil
      end
    end
  end

  describe 'started?' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :start_test
          variant :control
          variant :alternate
        end
      end
    }

    context 'when the experiment has been scheduled' do
      let(:start_time) { Time.now + 1.hour }
      before { subject.schedule!(start_time) }

      it 'returns false' do
        expect(subject.started?).to be_falsey
      end
    end

    context 'when the experiment has been started' do
      before { subject.start! }

      it 'returns true' do
        expect(subject.started?).to be_truthy
      end

      context 'and then stopped' do
        before { subject.stop! }

        it 'returns true' do
          expect(subject.started?).to be_truthy
        end
      end
    end

    context 'when the experiment has not been started' do
      it 'returns false' do
        expect(subject.started?).to be_falsey
      end
    end
  end

  describe 'scheduled?' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :schedule_test
          variant :control
          variant :alternate
        end
      end
    }

    context 'when the experiment has been scheduled' do
      let(:start_time) { Time.now + 1.hour }
      before { subject.schedule!(start_time) }

      it 'returns true' do
        expect(subject.scheduled?).to be_truthy
      end
    end

    context 'when the experiment has been started' do
      before { subject.start! }

      it 'returns false' do
        expect(subject.scheduled?).to be_falsey
      end
    end

    context 'when the experiment has not been scheduled' do
      it 'returns false' do
        expect(subject.scheduled?).to be_falsey
      end
    end
  end

  describe 'paused?' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :pause_test
          config.can_resume = true
          variant :control
          variant :alternate
        end
      end
    }

    context 'when the experiment has been started' do
      before { subject.start! }

      it 'returns false' do
        expect(subject.paused?).to be_falsey
      end

      context 'and has been paused' do
        before { subject.pause! }

        it 'returns true' do
          expect(subject.paused?).to be_truthy
        end
      end
    end

    context 'when the experiment has not been started' do
      it 'returns false' do
        expect(subject.paused?).to be_falsey
      end
    end
  end

  describe 'stopped?' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :stop_test
          variant :control
          variant :alternate
        end
      end
    }

    context 'when the experiment has been started' do
      before { subject.start! }

      it 'returns false' do
        expect(subject.stopped?).to be_falsey
      end

      context 'and has been stopped' do
        before { subject.stop! }

        it 'returns true' do
          expect(subject.stopped?).to be_truthy
        end
      end
    end

    context 'when the experiment has not been started' do
      it 'returns false' do
        expect(subject.stopped?).to be_falsey
      end
    end
  end

  describe 'running?' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :running_test
          config.can_resume = true
          variant :control
          variant :alternate
        end
      end
    }

    context 'when the experiment has been started' do
      before { subject.start! }

      it 'returns true' do
        expect(subject.running?).to be_truthy
      end

      context 'and has been paused' do
        before { subject.pause! }

        it 'returns false' do
          expect(subject.running?).to be_falsey
        end

        context 'and has been resumed' do
          before { subject.resume! }

          it 'returns true' do
            expect(subject.running?).to be_truthy
          end
        end
      end

      context 'and has been stopped' do
        before { subject.stop! }

        it 'returns false' do
          expect(subject.running?).to be_falsey
        end
      end
    end

    context 'when the experiment has not been started' do
      it 'returns false' do
        expect(subject.running?).to be_falsey
      end
    end
  end

  describe 'calibrating?' do
    context 'when configured to enable calibration' do
      subject {
        Class.new(described_class) do
          configure do |config|
            config.name = :calibrating_test
            config.enable_calibration = true
            config.start_manually = true
            variant :control
            variant :alternate
          end
        end
      }

      context 'and the experiment has not been started' do
        it 'returns true' do
          expect(subject.calibrating?).to be_truthy
        end

        context 'but is configured to start automatically' do
          subject {
            Class.new(described_class) do
              configure do |config|
                config.name = :calibrating_test
                config.enable_calibration = true
                config.start_manually = false
                variant :control
                variant :alternate
              end
            end
          }

          it 'returns false' do
            expect(subject.calibrating?).to be_falsey
          end
        end
      end

      context 'and the experiment has been started' do
        before { subject.start! }

        it 'returns false' do
          expect(subject.calibrating?).to be_falsey
        end
      end
    end

    context 'when configured to disable calibration' do
      subject {
        Class.new(described_class) do
          configure do |config|
            config.name = :calibrating_test
            config.enable_calibration = false
            config.start_manually = true
            variant :control
            variant :alternate
          end
        end
      }

      it 'returns false' do
        expect(subject.calibrating?).to be_falsey
      end
    end
  end

  describe 'persisted?' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :persisted_test
          variant :control
          variant :alternate
        end
      end
    }

    it 'checks if the storage key exists' do
      expect(TrailGuide.redis).to receive(:exists).with(subject.storage_key)
      subject.persisted?
    end

    context 'when the experiment has been saved' do
      before { subject.save! }

      it 'returns true' do
        expect(subject.persisted?).to be_truthy
      end
    end

    context 'when the experiment has not been saved' do
      it 'returns false' do
        expect(subject.persisted?).to be_falsey
      end
    end
  end

  describe 'save!' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :save_test
          variant :control
          variant :alternate
        end
      end
    }

    it 'calls save! on each of the variants' do
      subject.variants.each { |var| expect(var).to receive(:save!) }
      subject.save!
    end

    it 'stores a hash with the name in the storage key' do
      subject.variants.each { |var| allow(TrailGuide.redis).to receive(:hsetnx).with(var.storage_key, 'name', var.name) }
      expect(TrailGuide.redis).to receive(:hsetnx).with(subject.storage_key, 'name', subject.experiment_name)
      subject.save!
    end

    context 'with a combined experiment' do
      subject {
        Class.new(described_class) do
          configure do |config|
            config.name = :save_test
            config.combined = [:first_combo, :second_combo]
            variant :control
            variant :alternate
          end
        end
      }
      before { subject.register! }

      it 'calls save! on each of the child experiments' do
        subject.combined_experiments.each { |exp| expect(exp).to receive(:save!) }
        subject.save!
      end
    end
  end

  describe 'delete!' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :delete_test
          variant :control
          variant :alternate
        end
      end
    }

    it 'calls delete! on each of the variants' do
      subject.variants.each { |var| expect(var).to receive(:delete!) }
      subject.delete!
    end

    it 'deletes the hash stored under the storage key' do
      subject.variants.each { |var| allow(TrailGuide.redis).to receive(:del).with(var.storage_key) }
      expect(TrailGuide.redis).to receive(:del).with(subject.storage_key)
      subject.delete!
    end

    it 'runs callbacks' do
      expect(subject).to receive(:run_callbacks).with(:on_delete, nil)
      subject.delete!
    end

    it 'returns true' do
      expect(subject.delete!).to be_truthy
    end

    context 'when a context is passed in' do
      let(:ctx) { {foo: :bar} }

      it 'passes the context to callbacks' do
        expect(subject).to receive(:run_callbacks).with(:on_delete, ctx)
        subject.delete!(ctx)
      end
    end

    context 'with a combined experiment' do
      subject {
        Class.new(described_class) do
          configure do |config|
            config.name = :delete_test
            config.combined = [:first_combo, :second_combo]
            variant :control
            variant :alternate
          end
        end
      }
      before { subject.register! }

      it 'calls delete! on each of the child experiments' do
        subject.combined_experiments.each { |exp| expect(exp).to receive(:delete!) }
        subject.delete!
      end
    end
  end

  describe 'reset!' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :reset_test
          variant :control
          variant :alternate
        end
      end
    }

    it 'calls delete! then save!' do
      expect(subject).to receive(:delete!).ordered
      expect(subject).to receive(:save!).ordered
      subject.reset!
    end

    it 'runs callbacks' do
      allow(subject).to receive(:run_callbacks).with(:on_delete, nil)
      expect(subject).to receive(:run_callbacks).with(:on_reset, nil)
      subject.reset!
    end

    context 'when a context is passed in' do
      let(:ctx) { {foo: :bar} }

      it 'passes the context to callbacks' do
        allow(subject).to receive(:run_callbacks).with(:on_delete, ctx)
        expect(subject).to receive(:run_callbacks).with(:on_reset, ctx)
        subject.reset!(ctx)
      end
    end
  end

  describe 'storage_key' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :key_test
          variant :control
          variant :alternate
        end
      end
    }

    it 'returns the configured name' do
      expect(subject.storage_key).to eq(subject.experiment_name)
    end
  end

end
