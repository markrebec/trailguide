require 'rails_helper'

RSpec.describe TrailGuide::Participant do
  subject { described_class.new(nil, adapter: TrailGuide::Adapters::Participants::Anonymous) }

  describe '#initialize' do
    context 'with an adapter argument' do
      let(:adapter) { TrailGuide::Adapters::Participants::Cookie }
      let(:context) do
        Class.new do
          def cookies
            {}
          end
        end.new
      end
      subject { described_class.new(context, adapter: adapter) }

      it 'initializes the provided adapter' do
        expect(subject.adapter).to be_an_instance_of("#{adapter}::Adapter".constantize)
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
    let(:context) { nil }
    before  { TrailGuide.configuration.adapter = adapter }
    after   { TrailGuide.configuration.adapter = :multi } # fallback to our dummy app default config
    subject { described_class.new(context) }

    context 'when configured with the cookie adapter' do
      let(:adapter) { :cookie }
      let(:context) {
        Class.new do
          def cookies
            {}
          end
        end.new
      }

      it 'uses the cookie adapter' do
        expect(subject.adapter).to be_an_instance_of(TrailGuide::Adapters::Participants::Cookie::Adapter)
      end
    end

    context 'when configured with the session adapter' do
      let(:adapter) { :session }
      let(:context) {
        Class.new do
          def session
            {}
          end
        end.new
      }

      it 'uses the session adapter' do
        expect(subject.adapter).to be_an_instance_of(TrailGuide::Adapters::Participants::Session::Adapter)
      end
    end

    context 'when configured with the redis adapter' do
      let(:adapter) { :redis }

      it 'uses the redis adapter' do
        expect(subject.adapter).to be_an_instance_of(TrailGuide::Adapters::Participants::Redis::Adapter)
      end
    end

    context 'when configured with the anonymous adapter' do
      let(:adapter) { :anonymous }

      it 'uses the anonymous adapter' do
        expect(subject.adapter).to be_an_instance_of(TrailGuide::Adapters::Participants::Anonymous::Adapter)
      end
    end

    context 'when configured with the multi adapter' do
      let(:adapter) { :multi }

      it 'uses the anonymous adapter by default' do
        expect(subject.adapter).to be_an_instance_of(TrailGuide::Adapters::Participants::Anonymous::Adapter)
      end
    end

    context 'when configured with a custom adapter class' do
      let(:adapter) { 'TrailGuide::Adapters::Participants::Redis' }

      it 'uses the custom adapter class' do
        expect(subject.adapter).to be_an_instance_of(TrailGuide::Adapters::Participants::Redis::Adapter)
      end
    end

    context 'when configured incorrectly' do
      let(:adapter) { :cookie } # without a context that supports cookies this fails and falls back

      it 'falls back to the anonymous adapter' do
        expect(subject.adapter).to be_an_instance_of(TrailGuide::Adapters::Participants::Anonymous::Adapter)
      end

      context 'and failover callbacks are configured' do
        let(:callback) { -> (adp,err) { nil } }
        before { TrailGuide.configuration.on_adapter_failover = callback }
        after  { TrailGuide.configuration.on_adapter_failover = nil }

        it 'triggers adapter failover callbacks' do
          expect(callback).to receive(:call).with(TrailGuide::Adapters::Participants::Cookie, an_instance_of(TrailGuide::UnsupportedContextError))
          subject.adapter
        end
      end
    end
  end

  describe '#variant' do
    #context 'when the result has been memoized'
    context 'when the experiment is not calibrating or started' do
      experiment {
        variant :control
        variant :alternate
      }

      it 'returns nil' do
        expect(subject.variant(experiment)).to be_nil
      end
    end

    context 'when the experiment storage key does not exist' do
      experiment {
        variant :control
        variant :alternate
      }
      before { experiment.start! }

      it 'returns nil' do
        expect(subject.variant(experiment)).to be_nil
      end
    end

    context 'when the stored variant does not exist in the experiment' do
      experiment {
        variant :control
        variant :alternate
      }
      before { experiment.start! }
      before { subject.adapter[experiment.storage_key] = 'invalid' }

      it 'returns nil' do
        expect(subject.variant(experiment)).to be_nil
      end
    end

    context 'when the variant storage key does not exist' do
      experiment {
        variant :control
        variant :alternate
      }
      before { experiment.start! }
      before { subject.adapter[experiment.storage_key] = experiment.variants.first.name.to_s }

      it 'returns nil' do
        expect(subject.variant(experiment)).to be_nil
      end
    end

    context 'when the experiment is calibrating' do
      experiment { |cfg|
        cfg.enable_calibration = true
        variant :control
        variant :alternate
      }
      before { subject.adapter[experiment.storage_key] = variant.name.to_s }
      before { subject.adapter[variant.storage_key] = Time.now.to_i }

      context 'and the variant is the control' do
        variant(:control)

        it 'returns the variant' do
          expect(subject.variant(experiment)).to eq(variant)
        end
      end

      context 'and the variant is not the control' do
        variant(:alternate)

        it 'returns nil' do
          expect(subject.variant(experiment)).to be_nil
        end
      end
    end

    context 'when the experiment is started' do
      experiment {
        variant :control
        variant :alternate
      }
      variant(:random) { experiment.variants.sample }
      before { experiment.start! }
      before { subject.adapter[experiment.storage_key] = variant.name.to_s }

      context 'and the variant timestamp is newer than the experiment start timestamp' do
        before { subject.adapter[variant.storage_key] = Time.now.to_i }

        it 'returns the variant' do
          expect(subject.variant(experiment)).to eq(variant)
        end
      end

      context 'and the variant timestamp is older than the experiment start timestamp' do
        before { subject.adapter[variant.storage_key] = Time.now.to_i - 10 }

        it 'returns nil' do
          expect(subject.variant(experiment)).to be_nil
        end
      end
    end
  end

  describe '#participating?' do
    #context 'when the result has been memoized'
    context 'when the variant does not exist' do
      experiment {
        variant :control
        variant :alternate
      }

      it 'returns false' do
        expect(subject.participating?(experiment)).to be_falsey
      end
    end

    context 'when the include_control argument is true' do
      experiment {
        variant :control
        variant :alternate
      }
      before { experiment.start! }
      before { subject.adapter[experiment.storage_key] = variant.name.to_s }
      before { subject.adapter[variant.storage_key] = Time.now.to_i }

      context 'and the variant is the control' do
        variant(:control)

        it 'returns true' do
          expect(subject.participating?(experiment, true)).to be_truthy
        end
      end

      context 'and the variant is not the control' do
        variant(:alternate)

        it 'returns true' do
          expect(subject.participating?(experiment, true)).to be_truthy
        end
      end
    end

    context 'when the include_control argument is false' do
      experiment {
        variant :control
        variant :alternate
      }
      before { experiment.start! }
      before { subject.adapter[experiment.storage_key] = variant.name.to_s }
      before { subject.adapter[variant.storage_key] = Time.now.to_i }

      context 'and the variant is the control' do
        variant(:control)

        it 'returns false' do
          expect(subject.participating?(experiment, false)).to be_falsey
        end
      end

      context 'and the variant is not the control' do
        variant(:alternate)

        it 'returns true' do
          expect(subject.participating?(experiment, false)).to be_truthy
        end
      end
    end
  end

  describe '#converted?' do
    context 'when the experiment is not started' do
      context 'and the experiment is not calibrating' do
        experiment {
          variant :control
          variant :alternate
        }
        variant(:alternate)
        before { subject.adapter[experiment.storage_key] = variant.name.to_s }
        before { subject.adapter[variant.storage_key] = Time.now.to_i }

        it 'returns false' do
          expect(subject.converted?(experiment)).to be_falsey
        end
      end

      context 'and the experiment is calibrating' do
        experiment { |cfg|
          cfg.enable_calibration = true
          variant :control
          variant :alternate
        }
        variant(:alternate)
        before { subject.adapter[experiment.storage_key] = variant.name.to_s }
        before { subject.adapter[variant.storage_key] = Time.now.to_i }

        context 'but the variant is not the control' do
          it 'returns false' do
            expect(subject.converted?(experiment)).to be_falsey
          end
        end
      end
    end

    context 'when the experiment does not have any metrics' do
      experiment {
        variant :control
        variant :alternate
      }

      #context 'and the result has been memoized'
      context 'and a checkpoint argument was provided' do
        before { experiment.start! }

        it 'raises an InvalidGoalError' do
          expect { subject.converted?(experiment, :checkpoint) }.to raise_exception(TrailGuide::InvalidGoalError)
        end
      end

      context 'and the metric storage key does not exist' do
        before { experiment.start! }
        variant(:alternate)
        before { subject.adapter[experiment.storage_key] = variant.name.to_s }
        before { subject.adapter[variant.storage_key] = Time.now.to_i }

        it 'returns false' do
          expect(subject.converted?(experiment)).to be_falsey
        end
      end

      context 'and the experiment is not calibrating' do
        before { experiment.start! }
        variant(:alternate)
        before { subject.adapter[experiment.storage_key] = variant.name.to_s }
        before { subject.adapter[variant.storage_key] = Time.now.to_i }

        context 'and the conversion timestamp is newer than the experiment start timestamp' do
          before { subject.adapter["#{experiment.storage_key}:converted"] = Time.now.to_i }

          it 'returns true' do
            expect(subject.converted?(experiment)).to be_truthy
          end
        end

        context 'and the conversion timestamp is older than the experiment start timestamp' do
          before { subject.adapter["#{experiment.storage_key}:converted"] = Time.now.to_i - 10 }

          it 'returns false' do
            expect(subject.converted?(experiment)).to be_falsey
          end
        end
      end

      context 'and the experiment is calibrating' do
        experiment { |cfg|
          cfg.enable_calibration = true
          variant :control
          variant :alternate
        }
        before { subject.adapter[experiment.storage_key] = variant.name.to_s }
        before { subject.adapter[variant.storage_key] = Time.now.to_i }
        before { subject.adapter["#{experiment.storage_key}:converted"] = Time.now.to_i }

        context 'and the variant is the control' do
          variant(:control)

          it 'returns true' do
            expect(subject.converted?(experiment)).to be_truthy
          end
        end

        context 'but the variant is not the control' do
          variant(:alternate)

          it 'returns false' do
            expect(subject.converted?(experiment)).to be_falsey
          end
        end
      end
    end

    context 'when the experiment does have configured metrics' do
      experiment {
        variant :control
        variant :alternate
        metric  :first
        metric  :second
      }

      context 'and a checkpoint argument was provided' do
        #context 'and the result has been memoized'
        context 'but the checkpoint is not a valid metric' do
          before { experiment.start! }

          it 'raises an InvalidGoalError' do
            expect { subject.converted?(experiment, :third) }.to raise_exception(TrailGuide::InvalidGoalError)
          end
        end

        context 'and the metric storage key does not exist' do
          before { experiment.start! }

          it 'returns false' do
            expect(subject.converted?(experiment, :first)).to be_falsey
          end
        end

        context 'and the experiment is not calibrating' do
          variant(:alternate)
          metric(:first)
          before { experiment.start! }
          before { subject.adapter[experiment.storage_key] = variant.name.to_s }
          before { subject.adapter[variant.storage_key] = Time.now.to_i }

          context 'and the conversion timestamp is newer than the experiment start timestamp' do
            before { subject.adapter[metric.storage_key] = Time.now.to_i }

            it 'returns true' do
              expect(subject.converted?(experiment, :first)).to be_truthy
            end
          end

          context 'and the conversion timestamp is older than the experiment start timestamp' do
            before { subject.adapter[metric.storage_key] = Time.now.to_i - 10 }

            it 'returns false' do
              expect(subject.converted?(experiment, :first)).to be_falsey
            end
          end
        end

        context 'and the experiment is calibrating' do
          experiment { |cfg|
            cfg.enable_calibration = true
            variant :control
            variant :alternate
            metric  :first
            metric  :second
          }
          metric(:first)
          before { subject.adapter[experiment.storage_key] = variant.name.to_s }
          before { subject.adapter[variant.storage_key] = Time.now.to_i }
          before { subject.adapter[metric.storage_key] = Time.now.to_i }

          context 'and the variant is the control' do
            variant(:control)

            it 'returns true' do
              expect(subject.converted?(experiment, :first)).to be_truthy
            end
          end

          context 'but the variant is not the control' do
            variant(:alternate)

            it 'returns false' do
              expect(subject.converted?(experiment, :first)).to be_falsey
            end
          end
        end
      end

      context 'and a checkpoint argument was not provided' do
        #context 'and any results have been memoized'
        context 'and the experiment is not calibrating' do
          experiment { |cfg|
            variant :control
            variant :alternate
            metric  :first
            metric  :second
          }
          variant(:alternate)
          metric(:first)
          before { experiment.start! }
          before { subject.adapter[experiment.storage_key] = variant.name.to_s }
          before { subject.adapter[variant.storage_key] = Time.now.to_i }

          context 'and any of the conversion timestamps are newer than the experiment start timestamp' do
            before { subject.adapter[metric.storage_key] = Time.now.to_i }

            it 'returns true' do
              expect(subject.converted?(experiment)).to be_truthy
            end
          end

          context 'and none of the conversion timestamps are newer than the experiment start timestamp' do
            before { subject.adapter[metric.storage_key] = Time.now.to_i - 10 }

            it 'returns false' do
              expect(subject.converted?(experiment)).to be_falsey
            end
          end
        end

        context 'and the experiment is calibrating' do
          experiment { |cfg|
            cfg.enable_calibration = true
            variant :control
            variant :alternate
            metric  :first
            metric  :second
          }
          metric(:first)
          before { subject.adapter[experiment.storage_key] = variant.name.to_s }
          before { subject.adapter[variant.storage_key] = Time.now.to_i }

          context 'and the variant is the control' do
            variant(:control)
            before { subject.adapter[metric.storage_key] = Time.now.to_i }

            it 'returns true' do
              expect(subject.converted?(experiment)).to be_truthy
            end
          end

          context 'but the variant is not the control' do
            variant(:alternate)
            before { subject.adapter[metric.storage_key] = Time.now.to_i }

            it 'returns false' do
              expect(subject.converted?(experiment)).to be_falsey
            end
          end
        end
      end
    end
  end

  describe '#participating!' do
    experiment {
      variant :control
      variant :alternate
    }
    variant(:alternate)
    before { experiment.start! }
    before {
      allow(subject.adapter).to receive(:[]=).with(experiment.storage_key, variant.name)
      allow(subject.adapter).to receive(:[]=).with(variant.storage_key, kind_of(Numeric))
    }

    #it 'memoizes the result'
    it 'stores the variant under the experiment storage key' do
      expect(subject.adapter).to receive(:[]=).with(experiment.storage_key, variant.name)
      subject.participating!(variant)
    end

    it 'stores the timestamp under the variant storage key' do
      expect(subject.adapter).to receive(:[]=).with(variant.storage_key, kind_of(Numeric))
      subject.participating!(variant)
    end
  end

  describe '#converted!' do
    experiment { |cfg|
      variant :control
      variant :alternate
      metric  :first
      metric  :second
    }
    variant(:random) { experiment.variants.sample }
    metric(:random) { experiment.goals.sample }
    before { experiment.start! }

    context 'when a checkpoint is provided' do
      it 'uses the metric storage key' do
        expect(subject.adapter).to receive(:[]=).with(metric.storage_key, kind_of(Numeric))
        subject.converted!(variant, metric.name)
      end
    end

    context 'when no checkpoint is provided' do
      it 'uses a generic storage key' do
        expect(subject.adapter).to receive(:[]=).with("#{experiment.storage_key}:converted", kind_of(Numeric))
        subject.converted!(variant)
      end
    end

    context 'when the reset argument is true' do
      before {
        allow(subject.adapter).to receive(:delete).with(experiment.storage_key)
        allow(subject.adapter).to receive(:delete).with(variant.storage_key)
        experiment.goals.each { |m| allow(subject.adapter).to receive(:delete).with(m.storage_key) }
      }

      it 'deletes the experiment storage key immediately' do
        expect(subject.adapter).to receive(:delete).with(experiment.storage_key)
        subject.converted!(variant, metric.name, reset: true)
      end

      it 'deletes the variant storage key immediately' do
        expect(subject.adapter).to receive(:delete).with(variant.storage_key)
        subject.converted!(variant, metric.name, reset: true)
      end

      it 'deletes the metric storage key immediately' do
        expect(subject.adapter).to receive(:delete).with(metric.storage_key)
        subject.converted!(variant, metric.name, reset: true)
      end

      it 'deletes any other metric storage keys immediately' do
        experiment.goals.each { |m| expect(subject.adapter).to receive(:delete).with(m.storage_key) }
        subject.converted!(variant, metric.name, reset: true)
      end
    end
  end

  describe '#exit!' do
    experiment {
      variant :control
      variant :alternate
      metric  :first
      metric  :second
    }
    variant(:random) { experiment.variants.sample }
    metric(:random) { experiment.goals.sample }

    #it 'deletes any memoized participation'
    #it 'deletes any memoized conversion'
    #it 'deletes any memoized variants'
    context 'when the experiment has not been stored' do
      it 'does not delete any keys' do
        expect(subject.adapter).to_not receive(:delete)
        subject.exit!(experiment)
      end

      it 'returns true' do
        expect(subject.exit!(experiment)).to be_truthy
      end
    end

    context 'when the experiment has been stored' do
      before { experiment.start! }
      before { subject.adapter[experiment.storage_key] = variant.name.to_s }
      before { subject.adapter[variant.storage_key] = Time.now.to_i }
      before { subject.adapter[metric.storage_key] = Time.now.to_i }
      before {
        allow(subject.adapter).to receive(:delete).with(experiment.storage_key)
        allow(subject.adapter).to receive(:delete).with(variant.storage_key)
        allow(subject.adapter).to receive(:delete).with("#{experiment.storage_key}:converted")
        experiment.goals.each { |m| allow(subject.adapter).to receive(:delete).with(m.storage_key) }
      }

      it 'deletes the experiment storage key' do
        expect(subject.adapter).to receive(:delete).with(experiment.storage_key)
        subject.exit!(experiment)
      end

      it 'deletes the variant storage key' do
        expect(subject.adapter).to receive(:delete).with(variant.storage_key)
        subject.exit!(experiment)
      end

      it 'deletes the generic conversion storage key' do
        expect(subject.adapter).to receive(:delete).with("#{experiment.storage_key}:converted")
        subject.exit!(experiment)
      end

      it 'deletes the metric conversion storage keys' do
        experiment.goals.each { |m| expect(subject.adapter).to receive(:delete).with(m.storage_key) }
        subject.exit!(experiment)
      end

      it 'returns true' do
        expect(subject.exit!(experiment)).to be_truthy
      end
    end
  end

  describe '#active_experiments' do
    context 'when there are no stored experiments' do
      it 'returns false' do
        expect(subject.active_experiments).to be_falsey
      end
    end

    context 'when there are stored experiments' do
      experiment(:first_exp) {
        variant :control
        variant :alternate
      }
      experiment(:second_exp) {
        variant :control
        variant :alternate
      }
      experiment(:unstarted) {
        variant :control
        variant :alternate
      }
      experiment(:calibrating) { |cfg|
        cfg.enable_calibration = true
        variant :control
        variant :alternate
      }
      experiment(:not_sticky) { |cfg|
        cfg.sticky_assignment = false
        variant :control
        variant :alternate
      }
      experiment(:combined) { |cfg|
        variant :control
        variant :alternate
        cfg.combined = [:first_combo, :second_combo]
      }

      let(:experiments) { [first_exp, second_exp, not_sticky, combined] }
      before { experiments.each(&:start!) }


      it 'returns a hash of active experiments' do
        variant = first_exp.variants.sample
        subject.adapter[first_exp.storage_key] = variant.name.to_s
        subject.adapter[variant.storage_key] = Time.now.to_i
        expect(subject.active_experiments).to eq({first_exp.experiment_name => variant.name.to_s})
      end

      it 'excludes experiments without sticky assignment' do
        first_variant = first_exp.variants.sample
        subject.adapter[first_exp.storage_key] = first_variant.name.to_s
        subject.adapter[first_variant.storage_key] = Time.now.to_i
        not_sticky_variant = not_sticky.variants.sample
        subject.adapter[not_sticky.storage_key] = not_sticky_variant.name.to_s
        subject.adapter[not_sticky_variant.storage_key] = Time.now.to_i
        expect(subject.active_experiments).to eq({first_exp.experiment_name => first_variant.name.to_s})
      end

      it 'excludes combined experiments' do
        first_variant = first_exp.variants.sample
        subject.adapter[first_exp.storage_key] = first_variant.name.to_s
        subject.adapter[first_variant.storage_key] = Time.now.to_i
        combined_variant = combined.variants.sample
        subject.adapter[combined.storage_key] = combined_variant.name.to_s
        subject.adapter[combined_variant.storage_key] = Time.now.to_i
        combo = combined.combined_experiments.first
        combo_variant = combo.variants.sample
        subject.adapter[combo.storage_key] = combo_variant.name.to_s
        subject.adapter[combo_variant.storage_key] = Time.now.to_i
        expect(subject.active_experiments).to eq({
          first_exp.experiment_name => first_variant.name.to_s,
          combo.experiment_name => combo_variant.name.to_s
        })
      end

      it 'excludes experiments that are calibrating' do
        first_variant = first_exp.variants.sample
        subject.adapter[first_exp.storage_key] = first_variant.name.to_s
        subject.adapter[first_variant.storage_key] = Time.now.to_i
        calibrating_variant = calibrating.variants.find { |v| v == :control }
        subject.adapter[calibrating.storage_key] = calibrating_variant.name.to_s
        subject.adapter[calibrating_variant.storage_key] = Time.now.to_i
        expect(subject.active_experiments).to eq({first_exp.experiment_name => first_variant.name.to_s})
      end

      it 'excludes experiments that are not running' do
        first_variant = first_exp.variants.sample
        subject.adapter[first_exp.storage_key] = first_variant.name.to_s
        subject.adapter[first_variant.storage_key] = Time.now.to_i
        unstarted_variant = unstarted.variants.sample
        subject.adapter[unstarted.storage_key] = unstarted_variant.name.to_s
        subject.adapter[unstarted_variant.storage_key] = Time.now.to_i
        expect(subject.active_experiments).to eq({first_exp.experiment_name => first_variant.name.to_s})
      end

      context 'when the include_control argument is true' do
        it 'uses the argument when checking participation' do
          variant = first_exp.variants.sample
          subject.adapter[first_exp.storage_key] = variant.name.to_s
          subject.adapter[variant.storage_key] = Time.now.to_i
          expect(subject).to receive(:participating?).with(anything, true)
          subject.active_experiments(true)
        end

        it 'excludes experiments without valid participation' do
          first_variant = first_exp.variants.sample
          subject.adapter[first_exp.storage_key] = first_variant.name.to_s
          subject.adapter[first_variant.storage_key] = Time.now.to_i
          second_variant = second_exp.variants.sample
          subject.adapter[second_exp.storage_key] = second_variant.name.to_s
          subject.adapter[second_variant.storage_key] = Time.now.to_i - 10
          expect(subject.active_experiments(true)).to eq({first_exp.experiment_name => first_variant.name.to_s})
        end
      end

      context 'when the include_control argument is false' do
        it 'uses the argument when checking participation' do
          variant = first_exp.variants.sample
          subject.adapter[first_exp.storage_key] = variant.name.to_s
          subject.adapter[variant.storage_key] = Time.now.to_i
          expect(subject).to receive(:participating?).with(anything, false)
          subject.active_experiments(false)
        end

        it 'excludes experiments without valid participation' do
          first_variant = first_exp.variants.find { |v| v == :alternate }
          subject.adapter[first_exp.storage_key] = first_variant.name.to_s
          subject.adapter[first_variant.storage_key] = Time.now.to_i
          second_variant = second_exp.variants.sample
          subject.adapter[second_exp.storage_key] = second_variant.name.to_s
          subject.adapter[second_variant.storage_key] = Time.now.to_i - 10
          expect(subject.active_experiments(false)).to eq({first_exp.experiment_name => first_variant.name.to_s})
        end
      end

      context 'when configured to cleanup experiments inline' do
        before { TrailGuide.configuration.cleanup_participant_experiments = :inline }
        after  { TrailGuide.configuration.cleanup_participant_experiments = false }

        let(:first_var) { first_exp.variants.sample }
        before { subject.adapter[first_exp.storage_key] = first_var.name.to_s }
        before { subject.adapter[first_var.storage_key] = Time.now.to_i }

        context 'and there are inactive experiments stored' do
          let(:unstarted_var) { unstarted.variants.sample }
          before { subject.adapter[unstarted.storage_key] = unstarted_var.name.to_s }
          before { subject.adapter[unstarted_var.storage_key] = Time.now.to_i }

          it 'deletes the stored keys for the inactive experiments' do
            expect(subject.adapter).to receive(:delete).with(unstarted.storage_key)
            expect(subject.adapter).to receive(:delete).with(unstarted_var.storage_key)
            subject.active_experiments
          end
        end

        context 'but there are no inactive experiments stored' do
          it 'does not delete any stored keys' do
            expect(subject.adapter).to_not receive(:delete)
            subject.active_experiments
          end
        end
      end
    end
  end

  describe '#calibrating_experiments' do
    context 'when there are no stored experiments' do
      it 'returns false' do
        expect(subject.calibrating_experiments).to be_falsey
      end
    end

    context 'when there are stored experiments' do
      experiment(:started) {
        variant :control
        variant :alternate
      }
      experiment(:unstarted) {
        variant :control
        variant :alternate
      }
      experiment(:calibrating) { |cfg|
        cfg.enable_calibration = true
        variant :control
        variant :alternate
      }

      variant(:control) { calibrating.variants.find { |v| v == :control } }
      before { subject.adapter[calibrating.storage_key] = control.name.to_s }
      before { subject.adapter[control.storage_key] = Time.now.to_i }

      it 'returns a hash of calibrating experiments' do
        expect(subject.calibrating_experiments).to eq({calibrating.experiment_name => control.name.to_s})
      end

      context 'with a mix of calibrating and other lifecycles' do
        before { started.start! }
        variant(:random) { started.variants.sample }
        before { subject.adapter[started.storage_key] = random.name.to_s }
        before { subject.adapter[random.storage_key] = Time.now.to_i }

        it 'excludes experiments that are not calibrating' do
          expect(subject.calibrating_experiments).to eq({calibrating.experiment_name => control.name.to_s})
        end
      end
    end
  end

  describe '#participating_in_active_experiments?' do
    context 'when there are no stored experiments' do
      it 'returns false' do
        expect(subject.participating_in_active_experiments?).to be_falsey
      end
    end

    context 'when there are stored experiments' do
      experiment(:first_exp) {
        variant :control
        variant :alternate
      }
      experiment(:second_exp) {
        variant :control
        variant :alternate
      }
      experiment(:unstarted) {
        variant :control
        variant :alternate
      }
      experiment(:calibrating) { |cfg|
        cfg.enable_calibration = true
        variant :control
        variant :alternate
      }
      experiment(:not_sticky) { |cfg|
        cfg.sticky_assignment = false
        variant :control
        variant :alternate
      }
      experiment(:combined) { |cfg|
        variant :control
        variant :alternate
        cfg.combined = [:first_combo, :second_combo]
      }

      let(:experiments) { [first_exp, second_exp, not_sticky, combined] }
      before { experiments.each(&:start!) }


      it 'returns true' do
        variant = first_exp.variants.sample
        subject.adapter[first_exp.storage_key] = variant.name.to_s
        subject.adapter[variant.storage_key] = Time.now.to_i
        expect(subject.participating_in_active_experiments?).to be_truthy
      end

      it 'excludes experiments without sticky assignment' do
        not_sticky_variant = not_sticky.variants.sample
        subject.adapter[not_sticky.storage_key] = not_sticky_variant.name.to_s
        subject.adapter[not_sticky_variant.storage_key] = Time.now.to_i
        expect(subject.participating_in_active_experiments?).to be_falsey
      end

      it 'excludes combined experiments' do
        combined_variant = combined.variants.sample
        subject.adapter[combined.storage_key] = combined_variant.name.to_s
        subject.adapter[combined_variant.storage_key] = Time.now.to_i
        expect(subject.participating_in_active_experiments?).to be_falsey
      end

      it 'excludes experiments that are calibrating' do
        calibrating_variant = calibrating.variants.find { |v| v == :control }
        subject.adapter[calibrating.storage_key] = calibrating_variant.name.to_s
        subject.adapter[calibrating_variant.storage_key] = Time.now.to_i
        expect(subject.participating_in_active_experiments?).to be_falsey
      end

      it 'excludes experiments that are not running' do
        unstarted_variant = unstarted.variants.sample
        subject.adapter[unstarted.storage_key] = unstarted_variant.name.to_s
        subject.adapter[unstarted_variant.storage_key] = Time.now.to_i
        expect(subject.participating_in_active_experiments?).to be_falsey
      end

      context 'when the include_control argument is true' do
        it 'uses the argument when checking participation' do
          variant = first_exp.variants.sample
          subject.adapter[first_exp.storage_key] = variant.name.to_s
          subject.adapter[variant.storage_key] = Time.now.to_i
          expect(subject).to receive(:participating?).with(anything, true).at_least(:once)
          subject.participating_in_active_experiments?(true)
        end

        it 'excludes experiments without valid participation' do
          second_variant = second_exp.variants.sample
          subject.adapter[second_exp.storage_key] = second_variant.name.to_s
          subject.adapter[second_variant.storage_key] = Time.now.to_i - 10
          expect(subject.participating_in_active_experiments?(true)).to be_falsey
        end
      end

      context 'when the include_control argument is false' do
        it 'uses the argument when checking participation' do
          variant = first_exp.variants.sample
          subject.adapter[first_exp.storage_key] = variant.name.to_s
          subject.adapter[variant.storage_key] = Time.now.to_i
          expect(subject).to receive(:participating?).with(anything, false).at_least(:once)
          subject.participating_in_active_experiments?(false)
        end

        it 'excludes experiments without valid participation' do
          second_variant = second_exp.variants.sample
          subject.adapter[second_exp.storage_key] = second_variant.name.to_s
          subject.adapter[second_variant.storage_key] = Time.now.to_i - 10
          expect(subject.participating_in_active_experiments?(false)).to be_falsey
        end
      end
    end
  end

  describe '#cleanup_inactive_experiments!' do
    context 'when there are no stored experiments' do
      it 'returns false' do
        expect(subject.cleanup_inactive_experiments!).to be_falsey
      end
    end

    context 'when a stored experiment does not exist' do
      before { subject.adapter["fake_experiment"] = "control" }
      before { subject.adapter["fake_experiment:control"] = Time.now.to_i }

      it 'deletes the keys' do
        expect(subject.adapter).to receive(:delete).with("fake_experiment")
        expect(subject.adapter).to receive(:delete).with("fake_experiment:control")
        subject.cleanup_inactive_experiments!
      end
    end

    context 'when a stored experiment is not started or calibrating' do
      experiment {
        variant :control
        variant :alternate
      }
      variant(:alternate)
      before { subject.adapter[experiment.storage_key] = variant.name.to_s }
      before { subject.adapter[variant.storage_key] = Time.now.to_i }

      it 'deletes the keys' do
        expect(subject.adapter).to receive(:delete).with(experiment.storage_key)
        expect(subject.adapter).to receive(:delete).with(variant.storage_key)
        subject.cleanup_inactive_experiments!
      end
    end

    context 'when a stored experiment is started' do
      experiment {
        variant :control
        variant :alternate
      }
      variant(:alternate)
      before { experiment.start! }
      before { subject.adapter[experiment.storage_key] = variant.name.to_s }
      before { subject.adapter[variant.storage_key] = Time.now.to_i }

      it 'skips the keys' do
        expect(subject.adapter).to_not receive(:delete)
        subject.cleanup_inactive_experiments!
      end
    end

    context 'when a stored experiment is calibrating' do
      experiment { |cfg|
        cfg.enable_calibration = true
        variant :control
        variant :alternate
      }
      variant(:control)
      before { subject.adapter[experiment.storage_key] = variant.name.to_s }
      before { subject.adapter[variant.storage_key] = Time.now.to_i }

      it 'skips the keys' do
        expect(subject.adapter).to_not receive(:delete)
        subject.cleanup_inactive_experiments!
      end
    end
  end
end
