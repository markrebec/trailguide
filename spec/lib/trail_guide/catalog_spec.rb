require 'rails_helper'

RSpec.shared_examples "a catalog enumerator" do
  it 'returns a new catalog enumerator' do
    expect(subject.all).to be_an_instance_of(described_class)
  end
end

RSpec.describe TrailGuide::Catalog do
  describe '.catalog' do
    it 'returns an instance of the catalog' do
      expect(described_class.catalog).to be_an_instance_of(described_class)
    end

    it 'memoizes the instance as a singleton' do
      expect(described_class.catalog).to equal(described_class.catalog)
    end

    it 'proxies itself from the top-level namespace' do
      expect(TrailGuide.catalog).to equal(described_class.catalog)
    end
  end

  describe '.load_experiments' do
  end

  describe '.load_yaml_experiments' do
  end

  describe '.combined_experiment' do
  end

  describe '#initialize' do
    context 'when no arguments are provided' do
      it 'initializes an empty @experiments array' do
        expect(subject.instance_variable_get(:@experiments)).to eq([])
      end

      it 'initializes an empty @combined array' do
        expect(subject.instance_variable_get(:@combined)).to eq([])
      end
    end

    context 'when an experiments argument is provided' do
      experiment {
        variant :control
        variant :alternate
      }
      subject { described_class.new([experiment]) }

      it 'initializes the @experiments variable with the provided argument' do
        expect(subject.instance_variable_get(:@experiments)).to eq([experiment])
      end
    end

    context 'when a combined argument is provided' do
      experiment {
        variant :control
        variant :alternate
      }
      subject { described_class.new([], [experiment]) }

      it 'initializes the @combined variable with the provided argument' do
        expect(subject.instance_variable_get(:@combined)).to eq([experiment])
      end
    end
  end

  describe '#combined_experiment' do
  end

  describe '#each' do
    it 'delegates to the experiments array' do
      expect(subject.experiments).to receive(:each)
      subject.each
    end
  end

  describe '#groups' do
    subject { described_class.new(experiments) }

    context 'when there are no configured experiment groups' do
      let(:experiments) { [] }

      it 'returns an empty array' do
        expect(subject.groups).to eq([])
      end
    end

    context 'when there are experiments configured with groups' do
      experiment(:first_exp)  { groups :first_group, :second_group }
      experiment(:second_exp) { groups :first_group, :third_group }
      let(:experiments) { [first_exp, second_exp] }

      it 'returns a unique array of all defined groups' do
        expect(subject.groups).to eq([:first_group, :second_group, :third_group])
      end
    end
  end

  describe '#all' do
    experiment(:first)
    experiment(:second)
    subject { described_class.new([first, second]) }

    it_behaves_like 'a catalog enumerator'

    context 'when there are no combined experiments' do
      it 'returns the array of experiments' do
        expect(subject.all.to_a).to eq([first, second])
      end
    end

    context 'when there are combined experiments' do
      experiment(:combined) { |cfg|
        cfg.combined = [:combo_one, :combo_two]
      }
      subject { described_class.new([first, second, combined], combined.combined_experiments) }

      it 'explodes any combined experiments into their child experiments' do
        expect(subject.all.to_a).to eq([first, second].concat(combined.combined_experiments))
      end
    end
  end

  describe '#calibrating' do
    experiment(:calibrating) { |cfg|
      cfg.enable_calibration = true
    }
    experiment(:unstarted)
    subject { described_class.new([calibrating, unstarted]) }

    it_behaves_like 'a catalog enumerator'

    context 'when there are calibrating experiments' do
      it 'returns a list of calibrating experiments' do
        expect(subject.calibrating.to_a).to eq([calibrating])
      end
    end

    context 'when there are no calibrating experiments' do
      before { calibrating.start! }

      it 'returns an empty array' do
        expect(subject.calibrating.to_a).to eq([])
      end
    end
  end

  describe '#started' do
    experiment(:started)
    experiment(:unstarted)
    subject { described_class.new([started, unstarted]) }

    it_behaves_like 'a catalog enumerator'

    context 'when there are started experiments' do
      before { started.start! }

      it 'returns a list of started experiments' do
        expect(subject.started.to_a).to eq([started])
      end

      context 'but they have a winner selected' do
        before { started.declare_winner!(started.variants.first) }

        it 'excludes started experiments with a winner' do
          expect(subject.started.to_a).to eq([])
        end
      end
    end

    context 'when there are no started experiments' do
      it 'returns an empty array' do
        expect(subject.started.to_a).to eq([])
      end
    end
  end

  describe '#scheduled' do
    experiment(:scheduled)
    experiment(:unscheduled)
    subject { described_class.new([scheduled, unscheduled]) }

    it_behaves_like 'a catalog enumerator'

    context 'when there are scheduled experiments' do
      before { scheduled.schedule!(1.hour.from_now) }

      it 'returns a list of scheduled experiments' do
        expect(subject.scheduled.to_a).to eq([scheduled])
      end

      context 'but they have a winner selected' do
        before { scheduled.declare_winner!(scheduled.variants.first) }

        it 'excludes scheduled experiments with a winner' do
          expect(subject.scheduled.to_a).to eq([])
        end
      end
    end

    context 'when there are no scheduled experiments' do
      it 'returns an empty array' do
        expect(subject.scheduled.to_a).to eq([])
      end
    end
  end

  describe '#running' do
    experiment(:running)
    experiment(:not_running)
    subject { described_class.new([running, not_running]) }
    before  { running.start! }

    it_behaves_like 'a catalog enumerator'

    context 'when there are running experiments' do
      it 'returns a list of running experiments' do
        expect(subject.running.to_a).to eq([running])
      end

      context 'but they have a winner selected' do
        before { running.declare_winner!(running.variants.first) }

        it 'excludes running experiments with a winner' do
          expect(subject.running.to_a).to eq([])
        end
      end
    end

    context 'when there are no running experiments' do
      before { running.stop! }

      it 'returns an empty array' do
        expect(subject.running.to_a).to eq([])
      end
    end
  end

  describe '#paused' do
    experiment(:paused)
    experiment(:unpaused)
    subject { described_class.new([paused, unpaused]) }
    before { paused.start! }

    it_behaves_like 'a catalog enumerator'

    context 'when there are paused experiments' do
      before { paused.pause! }

      it 'returns a list of paused experiments' do
        expect(subject.paused.to_a).to eq([])
      end

      context 'but they have a winner selected' do
        before { paused.declare_winner!(paused.variants.first) }

        it 'excludes paused experiments with a winner' do
          expect(subject.paused.to_a).to eq([])
        end
      end
    end

    context 'when there are no paused experiments' do
      it 'returns an empty array' do
        expect(subject.paused.to_a).to eq([])
      end
    end
  end

  describe '#stopped' do
    experiment(:stopped)
    experiment(:unstopped)
    subject { described_class.new([stopped, unstopped]) }
    before { stopped.start! }

    it_behaves_like 'a catalog enumerator'

    context 'when there are stopped experiments' do
      before { stopped.stop! }

      it 'returns a list of stopped experiments' do
        expect(subject.stopped.to_a).to eq([stopped])
      end

      context 'but they have a winner selected' do
        before { stopped.declare_winner!(stopped.variants.first) }

        it 'excludes stopped experiments with a winner' do
          expect(subject.stopped.to_a).to eq([])
        end
      end
    end

    context 'when there are no stopped experiments' do
      it 'returns an empty array' do
        expect(subject.stopped.to_a).to eq([])
      end
    end
  end

  describe '#ended' do
    experiment(:winner)
    experiment(:no_winner)
    subject { described_class.new([winner, no_winner]) }

    it_behaves_like 'a catalog enumerator'

    context 'when there are experiments with a winner declared' do
      before { winner.declare_winner!(winner.variants.first) }

      it 'returns a list of ended experiments' do
        expect(subject.ended.to_a).to eq([winner])
      end
    end

    context 'when there are no experiments with a winner declared' do
      it 'returns an empty array' do
        expect(subject.ended.to_a).to eq([])
      end
    end
  end

  describe '#unstarted' do
    experiment(:unstarted)
    experiment(:started)
    experiment(:calibrating) { |cfg| cfg.enable_calibration = true }
    experiment(:scheduled)
    experiment(:winner)
    let(:catalog_experiments) { [unstarted, started, calibrating, scheduled, winner] }
    subject { described_class.new(catalog_experiments) }
    before { started.start! }
    before { scheduled.schedule!(1.hour.from_now) }
    before { winner.declare_winner!(winner.variants.first) }

    it_behaves_like 'a catalog enumerator'

    context 'when there are experiments that have not been started' do
      context 'and are not calibrating' do
        context 'and are not scheduled' do
          context 'and have not declared a winner' do
            it 'returns a list of unstarted experiments' do
              expect(subject.unstarted.to_a).to eq([unstarted])
            end
          end

          context 'but have declared a winner' do
            before { unstarted.declare_winner!(unstarted.variants.first) }

            it 'excludes experiments with a winner' do
              expect(subject.unstarted.to_a).to eq([])
            end
          end
        end

        context 'but are scheduled' do
          before { unstarted.schedule!(1.hour.from_now) }

          it 'excludes experiments which are scheduled' do
            expect(subject.unstarted.to_a).to eq([])
          end
        end
      end

      context 'but are calibrating' do
        before { unstarted.configure { |cfg| cfg.enable_calibration = true } }

        it 'excludes experiments which are calibrating' do
          expect(subject.unstarted.to_a).to eq([])
        end
      end
    end

    context 'when there are no unstarted experiments' do
      before { unstarted.start! }

      it 'returns an empty array' do
        expect(subject.unstarted.to_a).to eq([])
      end
    end
  end

  describe '#not_running' do
    experiment(:running)
    experiment(:not_running)
    subject { described_class.new([running, not_running]) }
    before  { running.start! }

    it_behaves_like 'a catalog enumerator'

    context 'when there are experiments that are not running' do
      it 'returns a list of not_running experiments' do
        expect(subject.not_running.to_a).to eq([not_running])
      end
    end

    context 'when there are only running experiments' do
      before { not_running.start! }

      it 'returns an empty array' do
        expect(subject.not_running.to_a).to eq([])
      end
    end
  end

  describe '#by_started' do
    it_behaves_like 'a catalog enumerator'

    it 'sorts experiments by their state'
  end

  describe '#find' do
    context 'when provided with an experiment class' do
      it 'returns the experiment'

      context 'for an unregistered experiment' do
        it 'returns nil'
      end
    end

    context 'when provided with a symbol' do
      it 'returns the experiment'

      context 'for an unregistered experiment' do
        it 'returns nil'
      end

      context 'for a combined experiment' do
        it 'returns the experiment'
      end

      context 'for a group' do
        it 'returns the first experiment in that group'
      end
    end

    context 'when provided with a string' do
      it 'returns the experiment'

      context 'for an unregistered experiment' do
        it 'returns nil'
      end

      context 'for a combined experiment' do
        it 'returns the experiment'
      end

      context 'for a group' do
        it 'returns the first experiment in that group'
      end
    end
  end

  describe '#select' do
    it_behaves_like 'a catalog enumerator'

    context 'when provided with an experiment class' do
      it 'returns an array of matching experiments'

      context 'for an unregistered experiment' do
        it 'returns an empty array'
      end
    end

    context 'when provided with a symbol' do
      it 'returns an array of matching experiments'

      context 'for an unregistered experiment' do
        it 'returns an empty array'
      end

      context 'for a combined experiment' do
        it 'returns an array of matching experiments'
      end

      context 'for a group' do
        it 'returns an array of matching experiments'
      end
    end

    context 'when provided with a string' do
      it 'returns an array of matching experiments'

      context 'for an unregistered experiment' do
        it 'returns an empty array'
      end

      context 'for a combined experiment' do
        it 'returns an array of matching experiments'
      end

      context 'for a group' do
        it 'returns an array of matching experiments'
      end
    end
  end

  describe '#register' do
    experiment

    it 'returns the registered experiment' do
      expect(subject.register(experiment)).to equal(experiment)
    end

    context 'when the experiment is already registered' do
      before { subject.register(experiment) }

      it 'does not add the experiment to the list' do
        expect { subject.register(experiment) }.to_not change { subject.experiments }
      end
    end

    context 'when the experiment has not been registered' do
      it 'adds the experiment to the list' do
        expect { subject.register(experiment) }.to change { subject.experiments }.to([experiment])
      end
    end
  end

  describe '#deregister' do
    experiment

    context 'when the experiment is registered' do
      before { subject.register(experiment) }

      it 'returns the deregistered experiment' do
        expect(subject.deregister(experiment)).to eq(experiment)
      end

      it 'removes the experiment from the list' do
        expect { subject.deregister(experiment) }.to change { subject.experiments }.to([])
      end

      context 'and is defined as a class constant' do
        before do
          Object.send(:remove_const, :ClassyExperiment) if defined?(ClassyExperiment)
          ClassyExperiment = Class.new(TrailGuide::Experiment) do
            configure do |config|
              config.name = :classy_experiment
              variant :control
              variant :alternate
            end
          end
          subject.register(ClassyExperiment)
        end

        context 'and the remove_const argument is false' do
          it 'does not remove the defined constant' do
            expect(Object).to_not receive(:remove_const)
            subject.deregister(:classy_experiment, false)
          end
        end

        context 'and the remove_const argument is true' do
          it 'returns the experiment key' do
            expect(subject.deregister(:classy_experiment, true)).to eq(:classy_experiment)
          end

          it 'removes the constant from the object namespace' do
            expect(Object).to receive(:remove_const).with("ClassyExperiment".to_sym)
            subject.deregister(:classy_experiment, true)
          end
        end
      end
    end

    context 'when the experiment is not registered' do
      it 'returns nil' do
        expect(subject.deregister(experiment)).to be_nil
      end

      it 'does not alter the experiments list' do
        expect { subject.deregister(experiment) }.to_not change { subject.experiments }
      end

      context 'and is defined as a class constant' do
        before do
          Object.send(:remove_const, :ClassyExperiment) if defined?(ClassyExperiment)
          ClassyExperiment = Class.new(TrailGuide::Experiment) do
            configure do |config|
              config.name = :classy_experiment
              variant :control
              variant :alternate
            end
          end
        end

        context 'and the remove_const argument is false' do
          it 'does not remove the defined constant' do
            expect(Object).to_not receive(:remove_const)
            subject.deregister(:classy_experiment, false)
          end
        end

        context 'and the remove_const argument is true' do
          it 'does not remove the defined constant' do
            expect(Object).to_not receive(:remove_const)
            subject.deregister(:classy_experiment, true)
          end
        end
      end
    end
  end

  describe '#export' do
  end

  describe '#import' do
  end

  describe '#missing' do
  end

  describe '#orphaned' do
  end

  describe '#orphans' do
  end

  describe '#adopted' do
  end
end
