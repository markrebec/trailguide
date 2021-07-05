require 'rails_helper'

# TODO should probably use timecop for some of the lifecycle stuff (started_at, paused_at, etc.)

RSpec.describe TrailGuide::Experiment do

  describe '.configuration' do
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
    describe ".#{method}" do
      subject {
        Class.new(described_class) do
          configure do |config|
            config.name = :config_test
            variant :control
            variant :alternate
          end
        end
      }

      it "delegates directly to the configuration object" do
        expect(subject.configuration).to receive(method)
        subject.send(method)
      end
    end
  end

  describe '.configure' do
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

  describe '.experiment_name' do
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

  describe '.register!' do
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

  describe '.variants' do
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

  describe '.is_combined?' do
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

  describe '.combined_experiments' do
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

  describe '.run_callbacks' do
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

  describe '.start!' do
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
        expect(subject.adapter).to_not receive(:set)
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
        expect(subject.adapter).to receive(:set).with(:started_at, kind_of(Numeric))
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

  describe '.schedule!' do
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
        expect(subject.adapter).to_not receive(:set)
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
        expect(subject.adapter).to receive(:set).with(:started_at, start_time.to_i)
        subject.schedule!(start_time)
      end

      it 'runs callbacks' do
        expect(subject).to receive(:run_callbacks).with(:on_schedule, start_time, nil, nil)
        subject.schedule!(start_time)
      end

      context 'with a stop_at argument' do
        let(:stop_time) { Time.now + 2.hours }

        it 'sets the stop_at storage key' do
          expect(subject.adapter).to receive(:set).with(:started_at, start_time.to_i)
          expect(subject.adapter).to receive(:set).with(:stopped_at, stop_time.to_i)
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

  describe '.pause!' do
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
        expect(subject.adapter).to_not receive(:set)
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
        expect(subject.adapter).to receive(:set).with(:paused_at, kind_of(Numeric))
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
        expect(subject.adapter).to_not receive(:set)
        subject.pause!
      end

      it 'does not fire callbacks' do
        expect(subject).to_not receive(:run_callbacks)
        subject.pause!
      end
    end
  end

  describe '.resume!' do
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
        expect(subject.adapter).to receive(:delete).with(:paused_at)
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
        expect(subject.adapter).to_not receive(:delete)
        subject.resume!
      end

      it 'does not fire callbacks' do
        expect(subject).to_not receive(:run_callbacks)
        subject.resume!
      end
    end
  end

  describe '.stop!' do
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
        expect(subject.adapter).to_not receive(:set)
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
        expect(subject.adapter).to_not receive(:set)
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
        expect(subject.adapter).to receive(:set).with(:stopped_at, kind_of(Numeric))
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

  describe '.started_at' do
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

  describe '.paused_at' do
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

  describe '.stopped_at' do
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

  describe '.started?' do
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

  describe '.scheduled?' do
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

  describe '.paused?' do
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

  describe '.stopped?' do
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

  describe '.running?' do
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

  describe '.calibrating?' do
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

  describe '.fresh?' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :fresh_test
          variant :control
          variant :alternate
        end
      end
    }

    context 'when the experiment is started' do
      before { subject.start! }

      it 'returns false' do
        expect(subject.fresh?).to be_falsey
      end
    end

    context 'when the experiment is scheduled' do
      before { subject.schedule!(1.hour.from_now) }

      it 'returns false' do
        expect(subject.fresh?).to be_falsey
      end
    end

    context 'when the experiment has a winner' do
      before { subject.declare_winner!(subject.variants.sample) }

      it 'returns false' do
        expect(subject.fresh?).to be_falsey
      end
    end

    context 'when the experiment is not started, not scheduled and does not have a winner' do
      it 'returns true' do
        expect(subject.fresh?).to be_truthy
      end
    end
  end

  describe '.declare_winner!' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :winner_test
          variant :control
          variant :alternate
        end
      end
    }

    context 'when provided with a variant' do
      context 'which belongs to the experiment' do
        it 'uses the variant' do
          expect(subject.declare_winner!(subject.variants.first)).to eq(subject.variants.first)
        end

        it 'runs callbacks' do
          expect(subject).to receive(:run_callbacks).with(:on_winner, subject.variants.first, nil)
          subject.declare_winner!(subject.variants.first)
        end

        it 'stores the winning variant' do
          expect(subject.adapter).to receive(:set).with(:winner, subject.variants.first.name)
          subject.declare_winner!(subject.variants.first)
        end

        context 'and provided with a context argument' do
          let(:ctx) { {foo: :bar} }

          it 'passes the provided context to callbacks' do
            expect(subject).to receive(:run_callbacks).with(:on_winner, subject.variants.first, ctx)
            subject.declare_winner!(subject.variants.first, ctx)
          end
        end
      end

      context 'which does not belong to the experiment' do
        let(:other) {
          Class.new(described_class) do
            configure do |config|
              config.name = :other_test
              variant :control
              variant :alternate
            end
          end
        }

        it 'returns false' do
          expect(subject.declare_winner!(other.variants.first)).to be_falsey
        end

        it 'does not run callbacks' do
          expect(subject).to_not receive(:run_callbacks)
          subject.declare_winner!(other.variants.first)
        end

        it 'does not store the winning variant' do
          expect(subject.adapter).to_not receive(:set)
          subject.declare_winner!(other.variants.first)
        end
      end
    end

    context 'when provided with a name' do
      context 'which matches a variant of the experiment' do
        it 'finds the variant' do
          expect(subject.declare_winner!(:control)).to eq(subject.variants.first)
        end

        it 'runs callbacks' do
          expect(subject).to receive(:run_callbacks).with(:on_winner, subject.variants.first, nil)
          subject.declare_winner!(:control)
        end

        it 'stores the winning variant' do
          expect(subject.adapter).to receive(:set).with(:winner, subject.variants.first.name)
          subject.declare_winner!(:control)
        end

        context 'and provided with a context argument' do
          let(:ctx) { {foo: :bar} }

          it 'passes the provided context to callbacks' do
            expect(subject).to receive(:run_callbacks).with(:on_winner, subject.variants.first, ctx)
            subject.declare_winner!(:control, ctx)
          end
        end
      end

      context 'which does not match a variant of the experiment' do
        it 'returns false' do
          expect(subject.declare_winner!(:nonexistent)).to be_falsey
        end

        it 'does not run callbacks' do
          expect(subject).to_not receive(:run_callbacks)
          subject.declare_winner!(:nonexistent)
        end

        it 'does not store the winning variant' do
          expect(subject.adapter).to_not receive(:set)
          subject.declare_winner!(:nonexistent)
        end
      end
    end
  end

  describe '.clear_winner!' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :winner_test
          variant :control
          variant :alternate
        end
      end
    }

    it 'deletes the stored winner' do
      expect(subject.adapter).to receive(:delete).with(:winner)
      subject.clear_winner!
    end
  end

  describe '.winner' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :winner_test
          variant :control
          variant :alternate
        end
      end
    }

    context 'when a winner has not been declared' do
      it 'returns nil' do
        expect(subject.winner).to be_nil
      end
    end

    context 'when a winner has been declared' do
      before { subject.declare_winner!(subject.variants.first) }

      it 'returns the winning variant' do
        expect(subject.winner).to eq(subject.variants.first)
      end
    end
  end

  describe '.winner?' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :winner_test
          variant :control
          variant :alternate
        end
      end
    }

    context 'when a winner has not been declared' do
      it 'returns false' do
        expect(subject.winner?).to be_falsey
      end
    end

    context 'when a winner has been declared' do
      before { subject.declare_winner!(subject.variants.first) }

      it 'returns true' do
        expect(subject.winner?).to be_truthy
      end
    end

    context 'with a combined experiment' do
      subject {
        Class.new(described_class) do
          configure do |config|
            config.name = :winner_test
            config.combined = [:first_combo, :second_combo]
            variant :control
            variant :alternate
          end
          register!
        end
      }

      context 'when a winnr has been declared for all child experiments' do
        before { subject.combined_experiments.each { |exp| exp.declare_winner!(exp.variants.first) } }

        it 'returns true' do
          expect(subject.winner?).to be_truthy
        end
      end

      context 'when a winner has been declared for some child experiments' do
        before { subject.combined_experiments.first.declare_winner!(subject.combined_experiments.first.variants.first) }

        it 'returns false' do
          expect(subject.winner?).to be_falsey
        end
      end

      context 'when no winner has been declared for any child experiments' do
        it 'returns false' do
          expect(subject.winner?).to be_falsey
        end
      end
    end
  end

  describe '.persisted?' do
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
      expect(subject.adapter).to receive(:persisted?)
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

  describe '.save!' do
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
      subject.variants.each { |var| allow(var.adapter).to receive(:setnx).with(:name, var.name) }
      expect(subject.adapter).to receive(:setnx).with(:name, subject.experiment_name)
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

  describe '.delete!' do
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
      subject.variants.each { |var| allow(var.adapter).to receive(:destroy) }
      expect(subject.adapter).to receive(:destroy)
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

  describe '.reset!' do
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

  describe '.participants' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :participants_test
          variant :control
          variant :alternate
        end
      end
    }

    it 'sums the participants across all variants' do
      expect(subject.variants).to receive(:sum) { |&block| expect(block).to eq(Proc.new(&:participants)) }
      subject.participants
    end
  end

  describe '.converted' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :participants_test
          variant :control
          variant :alternate
        end
      end
    }

    it 'sums the conversions across all variants' do
      expect(subject.variants).to receive(:sum)
      subject.converted
    end

    context 'when provided with a checkpoint' do
      subject {
        Class.new(described_class) do
          configure do |config|
            config.name = :participants_test
            variant :control
            variant :alternate
            metric  :checkpoint
          end
        end
      }

      it 'passes the checkpoint to variants when summing' do
        subject.variants.each { |var| expect(var).to receive(:converted).with(:checkpoint).and_return(0) }
        subject.converted(:checkpoint)
      end
    end
  end

  describe '.unconverted' do
    subject {
      Class.new(described_class) do
        configure do |config|
          config.name = :participants_test
          variant :control
          variant :alternate
        end
      end
    }
    before {
      allow(subject).to receive(:participants).and_return(200)
      allow(subject).to receive(:converted).and_return(100)
    }

    it 'subtracts all conversions from total participants' do
      expect(subject.unconverted).to eq(100)
    end
  end

  describe '.target_sample_size_reached?' do
    context 'when configured with a target sample size' do
      subject {
        Class.new(described_class) do
          configure do |config|
            config.name = :participants_test
            config.target_sample_size = 10
            variant :control
            variant :alternate
          end
        end
      }

      context 'and the target has not been reached' do
        it 'returns false' do
          expect(subject.target_sample_size_reached?).to be_falsey
        end
      end

      context 'and the target has been reached' do
        before { allow(subject).to receive(:participants).and_return(10) }

        it 'returns true' do
          expect(subject.target_sample_size_reached?).to be_truthy
        end
      end
    end

    context 'when not configured with a target sample size' do
      subject {
        Class.new(described_class) do
          configure do |config|
            config.name = :participants_test
            variant :control
            variant :alternate
          end
        end
      }

      it 'returns true' do
        expect(subject.target_sample_size_reached?).to be_truthy
      end
    end
  end

  describe '.storage_key' do
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


  [
    :allow_multiple_conversions?,
    :allow_multiple_goals?,
    :callbacks,
    :combined?,
    :configuration,
    :control,
    :enable_calibration?,
    :experiment_name,
    :goals,
    :is_combined?,
    :reset_manually?,
    :start_manually?,
    :storage_key,
    :track_winner_conversions?,
    :variants
  ].each do |method|
    describe "##{method}" do
      experiment
      participant
      subject { experiment.new(participant) }

      it 'delegates directly to the experiment class' do
        expect(subject.class).to receive(method)
        subject.send(method)
      end
    end
  end

  describe '#initialize' do
    experiment
    participant

    it 'initializes an experiment participant' do
      expect(TrailGuide::Experiments::Participant).to receive(:new).with(experiment, participant)
      experiment.new(participant)
    end

    it 'memoizes the experiment participant' do
      expect(experiment.new(participant).instance_variable_get(:@participant)).to be_an_instance_of(TrailGuide::Experiments::Participant)
    end
  end

  describe '#algorithm' do
    trial({algorithm: :random})
    subject { trial }

    it 'initializes an instance of the configured algorithm' do
      expect(subject.algorithm).to be_an_instance_of(TrailGuide::Algorithms::Random)
    end

    it 'memoizes the alrogithm instance' do
      expect { subject.algorithm }.to change { subject.instance_variable_get(:@algorithm) }
    end
  end

  describe '#winning_variant' do
    trial { |cfg| cfg.rollout_winner = -> (expmt, winner, ptcpt) { return expmt.control } }
    subject { trial }

    context 'when a winner has been declared' do
      before { experiment.declare_winner!(experiment.variants.last) }

      context 'and a rollout callback has been configured' do
        it 'returns the result of the rollout callback' do
          expect(subject.winning_variant).to eq(experiment.control)
        end
      end

      context 'and no rollout callback has been configured' do
        trial

        it 'returns the winning variant' do
          expect(subject.winning_variant).to eq(experiment.variants.last)
        end
      end
    end

    context 'when no winner has been delcared' do
      it 'returns nil' do
        expect(subject.winning_variant).to be_nil
      end

      it 'does not run rollout callbacks' do
        expect(subject).to_not receive(:run_callbacks)
        subject.winning_variant
      end
    end
  end

  describe '#choose!' do
    trial_subject

    it 'calls choose_variant! with the provided arguments' do
      expect(subject).to receive(:choose_variant!).with(override: :control, metadata: {foo: :bar})
      subject.choose!(override: :control, metadata: {foo: :bar})
    end

    it 'runs callbacks' do
      allow(subject).to receive(:choose_variant!).with(any_args).and_return(experiment.variants.last)
      allow(subject).to receive(:run_callbacks).with(:on_choose, any_args)
      expect(subject).to receive(:run_callbacks).with(:on_use, experiment.variants.last, subject.participant, nil)
      subject.choose!
    end

    it 'returns the variant' do
      allow(subject).to receive(:choose_variant!).with(any_args).and_return(experiment.variants.last)
      expect(subject.choose!).to eq(experiment.variants.last)
    end

    context 'when trailguide is globally disabled' do
      before { TrailGuide.configuration.disabled = true }
      before { experiment.start! }
      after  { TrailGuide.configuration.disabled = false }

      it 'returns control' do
        expect(subject.choose!).to eq(experiment.control)
      end
    end

    context 'when redis is unavailable' do
      before { allow(subject).to receive(:choose_variant!).and_raise(Errno::ECONNREFUSED) }

      it 'runs callbacks' do
        expect(subject).to receive(:run_callbacks).with(:on_redis_failover, instance_of(Errno::ECONNREFUSED))
        subject.choose!
      end

      it 'returns control' do
        expect(subject.choose!).to eq(experiment.control)
      end

      context 'and a valid override argument is present' do
        it 'returns the override variant' do
          expect(subject.choose!(override: :alternate)).to eq(experiment.variants.last)
        end
      end

      context 'and an invalid override argument is present' do
        it 'returns control' do
          expect(subject.choose!(override: :invalid)).to eq(experiment.control)
        end
      end
    end
  end

  describe '#choose_variant!' do
    experiment(:other)
    trial
    variant(:control)
    variant(:alternate)
    before { trial.start! }
    subject { trial }

    context 'when trailguide is globally disabled' do
      before { TrailGuide.configuration.disabled = true }
      after  { TrailGuide.configuration.disabled = false }

      it 'returns control' do
        expect(subject.choose_variant!).to eq(control)
      end

      it 'does not increment variant participation' do
        expect(control).to_not receive(:increment_participation!)
        subject.choose_variant!
      end

      it 'does not store participant assignment' do
        expect(participant).to_not receive(:participating!)
        subject.choose_variant!
      end
    end

    context 'when an override argument is present' do
      context 'and the experiment is running' do
        context 'and the experiment is not combined' do
          context 'and the experiment is configured to track overrides' do
            trial { |cfg| cfg.track_override = true }

            it 'increments variant participation' do
              expect(alternate).to receive(:increment_participation!)
              subject.choose_variant!(override: :alternate)
            end
          end

          context 'and the experiment is not configured to track overrides' do
            it 'does not increment variant participation' do
              expect(alternate).to_not receive(:increment_participation!)
              subject.choose_variant!(override: :alternate)
            end
          end

          context 'and the experiment is configured to store overrides' do
            trial { |cfg| cfg.store_override = true }

            context 'and configured with sticky assignment' do
              it 'stores participant assignment' do
                expect(participant).to receive(:participating!).with(alternate)
                subject.choose_variant!(override: :alternate)
              end
            end

            context 'and configured without sticky assignment' do
              trial { |cfg|
                cfg.store_override = true
                cfg.sticky_assignment = false
              }

              it 'does not store participant assignment' do
                expect(participant).to_not receive(:participating!)
                subject.choose_variant!(override: :alternate)
              end
            end
          end

          context 'and the experiment is not configured to store overrides' do
            it 'does not store participant assignment' do
              expect(participant).to_not receive(:participating!)
              subject.choose_variant!(override: :alternate)
            end
          end
        end
      end

      it 'returns the override variant' do
        expect(subject.choose_variant!(override: :alternate)).to be(alternate)
      end
    end

    context 'when a winner has been selected' do
      before { experiment.declare_winner!(alternate) }

      context 'and the experiment is configured to track winner conversions' do
        trial { |cfg| cfg.track_winner_conversions = true }

        context 'and the experiment is running' do
          context 'and the participant is not already assigned to the winner' do
            it 'increments variant participation' do
              expect(alternate).to receive(:increment_participation!)
              subject.choose_variant!
            end
          end

          context 'and the participant is already assigned to the winner' do
            before { participant.participating!(alternate) }

            it 'does not increment variant participation' do
              expect(alternate).to_not receive(:increment_participation!)
              subject.choose_variant!
            end
          end

          context 'and the participant is participating but their assigned variant does not match the winner' do
            before { participant.participating!(control) }

            it 'exits the experiment for reassignment' do
              expect(participant).to receive(:exit!).with(subject)
              subject.choose_variant!
            end
          end

          context 'and configured with sticky assignment' do
            it 'stores participant assignment' do
              expect(participant).to receive(:participating!).with(alternate)
              subject.choose_variant!
            end
          end

          context 'and configured without sticky assignment' do
            trial { |cfg|
              cfg.track_winner_conversions = true
              cfg.sticky_assignment = false
            }

            it 'does not store participant assignment' do
              expect(participant).to_not receive(:participating!)
              subject.choose_variant!
            end
          end
        end
      end

      it 'returns the winning variant' do
        expect(subject.choose_variant!).to be(alternate)
      end
    end

    context 'when the excluded argument is true' do
      it 'returns control' do
        expect(subject.choose_variant!(excluded: true)).to eq(control)
      end

      it 'does not increment variant participation' do
        expect(control).to_not receive(:increment_participation!)
        subject.choose_variant!(excluded: true)
      end

      it 'does not store participant assignment' do
        expect(participant).to_not receive(:participating!)
        subject.choose_variant!(excluded: true)
      end
    end

    context 'when the experiment has been stopped' do
      before { experiment.stop! }

      it 'returns control' do
        expect(subject.choose_variant!).to eq(control)
      end

      it 'does not increment variant participation' do
        expect(control).to_not receive(:increment_participation!)
        subject.choose_variant!
      end

      it 'does not store participant assignment' do
        expect(participant).to_not receive(:participating!)
        subject.choose_variant!
      end
    end

    context 'when the experiment has not been started' do
      before { experiment.reset! }

      context 'and is configured to start manually' do
        context 'and is configured to enable calibration' do
          trial { |cfg| cfg.enable_calibration = true }

          context 'and the participant is not already assigned to control' do
            it 'increments variant participation' do
              expect(control).to receive(:increment_participation!)
              subject.choose_variant!
            end

            context 'and it is a combined experiment' do
              trial { |cfg|
                cfg.enable_calibration = true
                cfg.combined = [:first, :last]
              }
              let(:combo) { trial.combined_experiments.first }
              subject { combo }

              it 'increments parent experiment variant participation' do
                expect(control).to receive(:increment_participation!)
                subject.choose_variant!
              end
            end
          end

          context 'and the participant is participating but their assigned variant is not the control' do
            before { allow(subject.participant.participant).to receive(:variant).and_return(alternate) }

            it 'exits the experiment for reassignment' do
              expect(participant).to receive(:exit!).with(subject)
              subject.choose_variant!
            end

            context 'and it is a combined experiment' do
              trial { |cfg|
                cfg.enable_calibration = true
                cfg.combined = [:first, :last]
              }
              let(:combo) { trial.combined_experiments.first }
              let(:alternate) { combo.variants.last }
              subject { combo }

              it 'exits the parent experiment for reassignment' do
                allow(participant).to receive(:exit!).with(subject)
                expect(participant).to receive(:exit!).with(subject.parent)
                subject.choose_variant!
              end
            end
          end

          context 'when configured with sticky assignment' do
            it 'stores participant assignment' do
              expect(participant).to receive(:participating!).with(control)
              subject.choose_variant!
            end
          end

          context 'when configured without sticky assignment' do
            trial { |cfg|
              cfg.enable_calibration = true
              cfg.sticky_assignment = false
            }

            it 'does not store participant assignment' do
              expect(participant).to_not receive(:participating!)
              subject.choose_variant!
            end
          end

          context 'and it is a combined experiment' do
            trial { |cfg|
              cfg.enable_calibration = true
              cfg.combined = [:first, :last]
            }
            let(:combo) { trial.combined_experiments.first }
            subject { combo }

            context 'when configured with sticky assignment' do
              it 'stores parent experiment participant assignment' do
                allow(participant).to receive(:participating!).with(combo.control)
                expect(participant).to receive(:participating!).with(control)
                subject.choose_variant!
              end
            end

            context 'when configured without sticky assignment' do
              trial { |cfg|
                cfg.enable_calibration = true
                cfg.sticky_assignment = false
                cfg.combined = [:first, :last]
              }

              it 'does not store parent experiment participant assignment' do
                expect(participant).to_not receive(:participating!).with(control)
                subject.choose_variant!
              end
            end
          end
        end

        it 'returns control' do
          expect(subject.choose_variant!).to be(control)
        end
      end

      context 'and is not scheduled to start in the future' do
        trial { |cfg| cfg.start_manually = false }

        it 'starts the experiment' do
          expect(experiment).to receive(:start!)
          subject.choose_variant!
        end
      end
    end

    context 'when the experiment is not running' do
      before { experiment.reset! }

      it 'returns control' do
        expect(subject.choose_variant!).to be(control)
      end
    end

    context 'when the experiment is configured with sticky assignment' do
      context 'and the participant is assigned' do
        before { participant.participating!(alternate) }

        it 'reinforces the assigned variant' do
          expect(participant).to receive(:participating!).with(alternate)
          subject.choose_variant!
        end

        it 'does not increment variant participation' do
          expect(alternate).to_not receive(:increment_participation!)
          subject.choose_variant!
        end

        it 'returns the assigned variant' do
          expect(subject.choose_variant!).to be(alternate)
        end
      end
    end

    context 'when the experiment is not combined' do
      context 'and trailguide is configured to not allow multiple experiments' do
        before  { TrailGuide.configuration.allow_multiple_experiments = false }

        context 'and the participant is participating in other experiments' do
          before {
            other.start!
            participant.participating!(other.control)
          }

          it 'returns control' do
            TrailGuide::SpecHelper.debug = true
            expect(subject.choose_variant!).to be(control)
            TrailGuide::SpecHelper.debug = false
          end
        end

        it 'includes control when checking participation' do
          expect(participant).to receive(:participating_in_active_experiments?).with(true)
          subject.choose_variant!
        end
      end

      context 'and trailguide is configured to only allow multiple experiments in control groups' do
        before { TrailGuide.configuration.allow_multiple_experiments = :control }
        after  { TrailGuide.configuration.allow_multiple_experiments = false }

        context 'and the participant is participating in other experiments control groups' do
          before {
            other.start!
            participant.participating!(other.control)
          }

          it 'chooses a variant' do
            expect(subject).to receive(:algorithm_choose!).and_call_original
            subject.choose_variant!
          end
        end

        context 'and the participant is participating in other experiments variant groups' do
          before {
            other.start!
            participant.participating!(other.variants.last)
          }

          it 'returns control' do
            expect(subject).to_not receive(:algorithm_choose!)
            expect(subject.choose_variant!).to be(control)
          end
        end

        it 'excludes control when checking participation' do
          expect(participant).to receive(:participating_in_active_experiments?).with(false)
          subject.choose_variant!
        end
      end

      context 'and trailguide is configured to allow multiple experiments' do
        before { TrailGuide.configuration.allow_multiple_experiments = true }
        after  { TrailGuide.configuration.allow_multiple_experiments = false }

        context 'and the participant is participating in other experiments variant groups' do
          before {
            other.start!
            participant.participating!(other.variants.last)
          }

          it 'chooses a variant' do
            expect(subject).to receive(:algorithm_choose!).and_call_original
            subject.choose_variant!
          end
        end
      end
    end

    context 'when configured not to allow participation for the participant' do
      trial { |cfg| cfg.allow_participation = -> (exp, all, ptc, mtd) { return false } }

      it 'returns control' do
        expect(subject).to_not receive(:algorithm_choose!)
        expect(subject.choose_variant!).to be(control)
      end
    end

    context 'when configured not to track participation for the participant' do
      trial { |cfg| cfg.track_participation = -> (exp, trk, ptc, mtd) { return false } }

      it 'uses the algorithm to choose a variant' do
        expect(subject).to receive(:algorithm_choose!).and_call_original
        subject.choose_variant!
      end

      it 'does not increment variant participation' do
        allow(subject).to receive(:algorithm_choose!).and_return(alternate)
        expect(alternate).to_not receive(:increment_participation!)
        subject.choose_variant!
      end

      it 'does not store participant assignment' do
        allow(subject).to receive(:algorithm_choose!).and_return(alternate)
        expect(participant).to_not receive(:participating!).with(alternate)
        subject.choose_variant!
      end

      context 'when configured with sticky assignment' do
        it 'does not store participant assignment' do
          allow(subject).to receive(:algorithm_choose!).and_return(alternate)
          expect(participant).to_not receive(:participating!)
          subject.choose_variant!
        end

        context 'when the participant is already participating' do
          before { participant.participating!(alternate) }

          it 'does not refresh participant assignment' do
            allow(subject).to receive(:algorithm_choose!).and_return(alternate)
            expect(participant).to_not receive(:participating!)
            subject.choose_variant!
          end
        end
      end
    end

    it 'uses the algorithm to choose a variant' do
      expect(subject).to receive(:algorithm_choose!).and_call_original
      subject.choose_variant!
    end

    it 'increments variant participation' do
      allow(subject).to receive(:algorithm_choose!).and_return(alternate)
      expect(alternate).to receive(:increment_participation!)
      subject.choose_variant!
    end

    context 'when configured with sticky assignment' do
      it 'stores participant assignment' do
        allow(subject).to receive(:algorithm_choose!).and_return(alternate)
        expect(participant).to receive(:participating!).with(alternate)
        subject.choose_variant!
      end

      context 'when the participant is already participating' do
        before { participant.participating!(alternate) }

        it 'refreshes participant assignment' do
          allow(subject).to receive(:algorithm_choose!).and_return(alternate)
          expect(participant).to receive(:participating!).with(alternate)
          subject.choose_variant!
        end
      end
    end

    context 'when configured without sticky assignment' do
      trial { |cfg| cfg.sticky_assignment = false }

      it 'does not store participant assignment' do
        allow(subject).to receive(:algorithm_choose!).and_return(alternate)
        expect(participant).to_not receive(:participating!).with(alternate)
        subject.choose_variant!
      end
    end

    it 'runs callbacks' do
      allow(subject).to receive(:algorithm_choose!).and_return(alternate)
      expect(subject).to receive(:run_callbacks).with(:on_choose, alternate, subject.participant, nil)
      subject.choose_variant!
    end

    it 'returns the chosen variant' do
      allow(subject).to receive(:algorithm_choose!).and_return(alternate)
      expect(subject.choose_variant!).to be(alternate)
    end
  end

  describe '#algorithm_choose!' do
    trial_subject

    it 'calls choose! on the algorithm' do
      expect(subject.algorithm).to receive(:choose!)
      subject.algorithm_choose!
    end

    it 'passes metadata through to the algorithm' do
      expect(subject.algorithm).to receive(:choose!).with(metadata: {foo: :bar})
      subject.algorithm_choose!(metadata: {foo: :bar})
    end
  end

  describe '#convert!' do
    trial
    variant(:control)
    variant(:alternate)
    let(:assigned) { alternate }
    subject { trial }
    before { experiment.start! }
    before { participant.participating!(assigned) }

    context 'when the experiment is not started' do
      before { experiment.reset! }

      context 'and is not calibrating' do
        it 'does not convert' do
          expect(participant).to_not receive(:converted!)
          expect(assigned).to_not receive(:increment_conversion!)
          subject.convert!
        end

        it 'returns false' do
          expect(subject.convert!).to be_falsey
        end
      end

      context 'and is calibrating' do
        trial { |cfg| cfg.enable_calibration = true }

        context 'and the user is not participating' do
          before { participant.exit!(experiment) }

          it 'does not convert' do
            expect(participant).to_not receive(:converted!)
            expect(assigned).to_not receive(:increment_conversion!)
            subject.convert!
          end

          it 'returns false' do
            expect(subject.convert!).to be_falsey
          end
        end

        context 'and the user is participating' do
          context 'but the assigned variant is not control' do
            it 'does not convert' do
              expect(participant).to_not receive(:converted!)
              expect(assigned).to_not receive(:increment_conversion!)
              subject.convert!
            end

            it 'returns false' do
              expect(subject.convert!).to be_falsey
            end
          end

          context 'and the assigned variant is control' do
            let(:assigned) { control }

            it 'stores participant conversion' do
              expect(participant).to receive(:converted!).with(assigned, nil, reset: false)
              subject.convert!
            end

            it 'increments variant conversion' do
              expect(assigned).to receive(:increment_conversion!)
              subject.convert!
            end

            it 'runs callbacks' do
              expect(subject).to receive(:run_callbacks).with(:on_convert, nil, assigned, subject.participant, nil)
              subject.convert!
            end

            it 'returns the variant' do
              expect(subject.convert!).to be(assigned)
            end
          end
        end
      end
    end

    context 'when the experiment is started' do
      context 'but not running' do
        before { experiment.stop! }

        it 'does not convert' do
          expect(participant).to_not receive(:converted!)
          expect(assigned).to_not receive(:increment_conversion!)
          subject.convert!
        end

        it 'returns false' do
          expect(subject.convert!).to be_falsey
        end
      end

      context 'and the participant is not participating' do
        before { participant.exit!(experiment) }

        it 'does not convert' do
          expect(participant).to_not receive(:converted!)
          expect(assigned).to_not receive(:increment_conversion!)
          subject.convert!
        end

        it 'returns false' do
          expect(subject.convert!).to be_falsey
        end
      end

      context 'and a winner has been selected' do
        let(:winner) { alternate }
        before { experiment.declare_winner!(winner) }

        context 'and the experiment is not configured to track winner conversions' do
          it 'does not convert' do
            expect(participant).to_not receive(:converted!)
            expect(assigned).to_not receive(:increment_conversion!)
            subject.convert!
          end

          it 'returns false' do
            expect(subject.convert!).to be_falsey
          end
        end

        context 'and the experiment is configured to track winner conversions' do
          trial { |cfg| cfg.track_winner_conversions = true }

          context 'but the participant is not assigned to the winning variant' do
            let(:assigned) { control }

            it 'does not convert' do
              expect(participant).to_not receive(:converted!)
              expect(assigned).to_not receive(:increment_conversion!)
              subject.convert!
            end

            it 'returns false' do
              expect(subject.convert!).to be_falsey
            end
          end
        end
      end
    end

    context 'when the experiment has defined goals' do
      trial { |cfg| cfg.goals = [:first, :last] }

      context 'but no checkpoint was provided' do
        it 'does not convert' do
          expect(participant).to_not receive(:converted!)
          expect(assigned).to_not receive(:increment_conversion!)
          subject.convert! rescue nil
        end

        it 'raises an InvalidGoalError' do
          expect { subject.convert! }.to raise_exception(TrailGuide::InvalidGoalError)
        end
      end

      context 'and a valid goal was provided' do
        let(:goal) { experiment.goals.first }

        context 'and the participant has already converted the goal' do
          before { participant.converted!(assigned, goal) }

          context 'but the goal allows multiple conversions' do
            trial { |cfg|
              goal(:first) { |g| g.allow_multiple_conversions = true }
              goal(:last)
            }

            it 'stores participant conversion' do
              expect(participant).to receive(:converted!).with(assigned, goal, reset: false)
              subject.convert!(goal.name)
            end

            it 'increments variant conversion' do
              expect(assigned).to receive(:increment_conversion!)
              subject.convert!(goal.name)
            end

            it 'runs callbacks' do
              expect(goal).to receive(:run_callbacks).with(:on_convert, subject, assigned, subject.participant, nil)
              subject.convert!(goal.name)
            end

            it 'returns the variant' do
              expect(subject.convert!(goal.name)).to be(assigned)
            end
          end

          context 'and the goal does not allow multiple conversions' do
            it 'does not convert' do
              expect(participant).to_not receive(:converted!)
              expect(assigned).to_not receive(:increment_conversion!)
              subject.convert!(goal.name)
            end

            it 'returns false' do
              expect(subject.convert!(goal.name)).to be_falsey
            end
          end
        end

        context 'and the participant has not already converted the goal' do
          context 'but has already converted another goal' do
            before { participant.converted!(assigned, experiment.goals.last) }

            context 'and the experiment allows multiple goals' do
              trial { |cfg|
                cfg.goals = [:first, :last]
                cfg.allow_multiple_goals = true
              }

              it 'stores participant conversion' do
                expect(participant).to receive(:converted!).with(assigned, goal, reset: false)
                subject.convert!(goal.name)
              end

              it 'increments variant conversion' do
                expect(assigned).to receive(:increment_conversion!)
                subject.convert!(goal.name)
              end

              it 'runs callbacks' do
                expect(goal).to receive(:run_callbacks).with(:on_convert, subject, assigned, subject.participant, nil)
                subject.convert!(goal.name)
              end

              it 'returns the variant' do
                expect(subject.convert!(goal.name)).to be(assigned)
              end
            end

            context 'and the experiment does not allow multiple goals' do
              it 'does not convert' do
                expect(participant).to_not receive(:converted!)
                expect(assigned).to_not receive(:increment_conversion!)
                subject.convert!(goal.name)
              end

              it 'returns false' do
                expect(subject.convert!(goal.name)).to be_falsey
              end
            end
          end
        end
      end

      context 'and an invalid goal was provided' do
        it 'does not convert' do
          expect(participant).to_not receive(:converted!)
          expect(assigned).to_not receive(:increment_conversion!)
          subject.convert!(:foobar) rescue nil
        end

        it 'raises an InvalidGoalError' do
          expect { subject.convert!(:foobar) }.to raise_exception(TrailGuide::InvalidGoalError)
        end
      end
    end

    context 'when the experiment does not have defined goals' do
      context 'but a checkpoint was provided' do
        it 'does not convert' do
          expect(participant).to_not receive(:converted!)
          expect(assigned).to_not receive(:increment_conversion!)
          subject.convert!(:foobar) rescue nil
        end

        it 'raises an InvalidGoalError' do
          expect { subject.convert!(:foobar) }.to raise_exception(TrailGuide::InvalidGoalError)
        end
      end

      context 'and no checkpoint was provided' do
        context 'and the participant has already converted' do
          before { participant.converted!(assigned) }

          context 'but the experiment allows multiple conversions' do
            trial { |cfg| cfg.allow_multiple_conversions = true }

            it 'stores participant conversion' do
              expect(participant).to receive(:converted!).with(assigned, nil, reset: false)
              subject.convert!
            end

            it 'increments variant conversion' do
              expect(assigned).to receive(:increment_conversion!)
              subject.convert!
            end

            it 'runs callbacks' do
              expect(subject).to receive(:run_callbacks).with(:on_convert, nil, assigned, subject.participant, nil)
              subject.convert!
            end

            it 'returns the variant' do
              expect(subject.convert!).to be(assigned)
            end
          end

          context 'and the experiment does not allow multiple conversions' do
            it 'does not convert' do
              expect(participant).to_not receive(:converted!)
              expect(assigned).to_not receive(:increment_conversion!)
              subject.convert!
            end

            it 'returns false' do
              expect(subject.convert!).to be_falsey
            end
          end
        end
      end
    end

    context 'when the experiment is configured not to allow conversion' do
      trial { allow_conversion { |exp,rslt,var,goal,ptcpt,mtdt| false } }

      it 'does not convert' do
        expect(participant).to_not receive(:converted!)
        expect(assigned).to_not receive(:increment_conversion!)
        subject.convert!
      end

      it 'returns false' do
        expect(subject.convert!).to be_falsey
      end
    end

    it 'stores participant conversion' do
      expect(participant).to receive(:converted!).with(assigned, nil, reset: false)
      subject.convert!
    end

    it 'increments variant conversion' do
      expect(assigned).to receive(:increment_conversion!)
      subject.convert!
    end

    it 'runs callbacks' do
      expect(subject).to receive(:run_callbacks).with(:on_convert, nil, assigned, subject.participant, nil)
      subject.convert!
    end

    it 'returns the variant' do
      expect(subject.convert!).to be(assigned)
    end
  end

  describe '#allow_participation?' do
    context 'when no allow_participation callbacks are defined' do
      trial_subject

      it 'returns true' do
        expect(subject.allow_participation?).to be_truthy
      end

      it 'does not run callbacks' do
        expect(subject).to_not receive(:run_callbacks)
        subject.allow_participation?
      end
    end

    context 'when allow_participation callbacks are defined' do
      trial_subject { |cfg| cfg.allow_participation = -> (expmt, allowed, ptcpt, mtdt) { return false } }

      it 'runs callbacks' do
        expect(subject).to receive(:run_callbacks).with(:allow_participation, true, subject.participant, nil)
        subject.allow_participation?
      end

      it 'returns the result of callbacks' do
        expect(subject.allow_participation?).to be_falsey
      end
    end
  end

  describe '#allow_conversion?' do
    context 'when a checkpoint is provided' do
      trial_subject { metric :test_goal }
      metric(:test_goal)
      variant(:alternate)

      it 'calls allow_conversion? on the checkpoint' do
        expect(metric).to receive(:allow_conversion?).with(subject, variant, nil)
        subject.allow_conversion?(variant, metric)
      end

      it 'passes the metadata through to the checkpoint' do
        expect(metric).to receive(:allow_conversion?).with(subject, variant, {foo: :bar})
        subject.allow_conversion?(variant, metric, {foo: :bar})
      end
    end

    context 'when no checkpoint is provided' do
      trial_subject
      variant(:alternate)

      context 'and no allow_conversion callbacks are defined' do
        it 'does not run callbacks' do
          expect(subject).to_not receive(:run_callbacks)
          subject.allow_conversion?(variant)
        end

        it 'returns true' do
          expect(subject.allow_conversion?(variant)).to be_truthy
        end
      end

      context 'and allow_conversion callbacks are defined' do
        trial_subject { |cfg| cfg.allow_conversion = -> (expmt, allowed, chkpt, vrnt, ptcpt, mtdt) { return false } }

        it 'runs callbacks' do
          expect(subject).to receive(:run_callbacks).with(:allow_conversion, true, nil, variant, subject.participant, nil)
          subject.allow_conversion?(variant)
        end

        it 'returns the result of callbacks' do
          expect(subject.allow_conversion?(variant)).to be_falsey
        end
      end
    end
  end

  describe '#track_participation?' do
    context 'when no track_participation callbacks are defined' do
      trial_subject

      it 'returns true' do
        expect(subject.track_participation?).to be_truthy
      end

      it 'does not run callbacks' do
        expect(subject).to_not receive(:run_callbacks)
        subject.track_participation?
      end
    end

    context 'when track_participation callbacks are defined' do
      trial_subject { |cfg| cfg.track_participation = -> (expmt, track, ptcpt, mtdt) { return false } }

      it 'runs callbacks' do
        expect(subject).to receive(:run_callbacks).with(:track_participation, true, subject.participant, nil)
        subject.track_participation?
      end

      it 'returns the result of callbacks' do
        expect(subject.track_participation?).to be_falsey
      end
    end
  end

  describe '#run_callbacks' do
    trial
    variant(:control)
    subject { trial }

    context 'with an unsupported callback' do
      it 'returns false' do
        expect(subject.run_callbacks(:foobar)).to be_falsey
      end
    end

    context 'when the callback is a block' do
      let(:block) { -> (trial,result,goal,var,ptcpt,metadata) { } }

      context 'and is a normal callback' do
        before { subject.configuration.on_choose = [block] }

        it 'executes the block' do
          expect(block).to receive(:call).with(subject, control, subject.participant, {foo: :bar})
          subject.run_callbacks(:on_choose, control, subject.participant, {foo: :bar})
        end
      end

      context 'and is a reduced callback' do
        before { subject.configuration.allow_participation = [block] }

        it 'reduces the results' do
          subject.configuration.allow_participation = [-> (trl,rslt,ptcpt,mtdt) { rslt + 1 } ]
          expect(subject.run_callbacks(:allow_participation, 1, subject.participant, {foo: :bar})).to eq(2)
        end

        it 'executes the block' do
          expect(block).to receive(:call).with(subject, true, subject.participant, {foo: :bar})
          subject.run_callbacks(:allow_participation, true, subject.participant, {foo: :bar})
        end
      end
    end

    context 'when the callback is a method symbol' do
      before { trial.define_singleton_method(:foobar) { |*args| nil } }

      context 'and is a normal callback' do
        before { subject.configuration.on_choose = [:foobar] }

        it 'executes the block' do
          expect(subject).to receive(:foobar).with(subject, control, subject.participant, {foo: :bar})
          subject.run_callbacks(:on_choose, control, subject.participant, {foo: :bar})
        end
      end

      context 'and is a reduced callback' do
        before { subject.configuration.allow_participation = [:foobar] }

        it 'reduces the results' do
          subject.define_singleton_method(:foobar) { |trl,rslt,ptcpt,mtdt| rslt + 1 }
          expect(subject.run_callbacks(:allow_participation, 1, subject.participant, {foo: :bar})).to eq(2)
        end

        it 'calls the method on the trial' do
          expect(subject).to receive(:foobar).with(subject, true, subject.participant, {foo: :bar})
          subject.run_callbacks(:allow_participation, true, subject.participant, {foo: :bar})
        end
      end
    end
  end

  describe '#combined_experiments' do
    trial_subject

    it 'memoizes the combined experiments' do
      expect { subject.combined_experiments }.to change { subject.instance_variable_get(:@combined_experiments) }
    end

    context 'when the experiment is not a combined experiment' do
      it 'returns an empty array' do
        expect(subject.combined_experiments).to eq([])
      end
    end

    context 'when the experiment is a combined experiment' do
      combined
      participant
      subject { experiment.new(participant) }

      it 'returns an array of child experiments' do
        expect(subject.combined_experiments.count).to be(2)
        subject.combined_experiments.each do |ce|
          expect(ce.class).to be < TrailGuide::CombinedExperiment
        end
      end
    end
  end

  # TODO memoization methods (maybe re-work all that in favor of "trials" instead...)

end
