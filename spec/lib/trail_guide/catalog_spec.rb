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

  describe '.load_experiments!' do
    let(:ruby_config) { Rails.root.join("tmp/ruby_config.rb") }
    let(:yaml_config) { Rails.root.join("tmp/yaml_config.yml") }

    before {
      FileUtils.touch(ruby_config)
      FileUtils.touch(yaml_config)
    }
    after  {
      FileUtils.rm_f(ruby_config)
      FileUtils.rm_f(yaml_config)
    }

    it 'resets the catalog singleton' do
      expect { described_class.load_experiments! }.to change { described_class.instance_variable_get(:@catalog) }
    end

    context 'when loading configs' do
      context 'with a file path' do
        it 'loads yaml experiments' do
          expect(described_class).to receive(:load_yaml_experiments)
          described_class.load_experiments!(configs: [yaml_config])
        end

        it 'evals ruby experiments' do
          expect(TrailGuide::Catalog::DSL).to receive(:instance_eval)
          described_class.load_experiments!(configs: [ruby_config])
        end
      end

      context 'with a glob pattern' do
        it 'loads yaml experiments' do
          expect(described_class).to receive(:load_yaml_experiments).with(yaml_config.to_s)
          described_class.load_experiments!(configs: ["tmp/**/*"])
        end

        it 'evals ruby experiments' do
          expect(File).to receive(:read).with(ruby_config.to_s)
          expect(TrailGuide::Catalog::DSL).to receive(:instance_eval)
          described_class.load_experiments!(configs: ["tmp/**/*"])
        end
      end
    end

    context 'when loading classes' do
      let(:ruby_class) { Rails.root.join("tmp/ruby_class.rb") }

      before {
        File.open(ruby_class, 'w') { |f|
          f.write("class KlassExperiment < TrailGuide::Experiment; end")
        }
      }
      after  {
        Object.send(:remove_const, :KlassExperiment) if defined?(KlassExperiment)
        FileUtils.rm_f(ruby_class)
      }

      context 'with a file path' do
        it 'loads the experiment class' do
          described_class.load_experiments!(classes: [ruby_class])
          expect(defined?(KlassExperiment)).to be_truthy
        end
      end

      context 'with a glob pattern' do
        it 'loads the experiment class' do
          described_class.load_experiments!(classes: ["tmp/**/*.rb"])
          expect(defined?(KlassExperiment)).to be_truthy
        end
      end
    end
  end

  describe '.load_yaml_experiments' do
    pending
  end

  describe '.combined_experiment' do
    combined(:combo, combined: [:first_combo]) { goals [:first_goal, :last_goal] }

    it 'returns a combined experiment' do
      expect(described_class.combined_experiment(combo, :first_combo)).to be < TrailGuide::CombinedExperiment
    end

    it 'uses the provided experiment as the parent' do
      expect(described_class.combined_experiment(combo, :first_combo).configuration.parent).to eq(combo)
    end

    it 'clears the combined config' do
      expect(described_class.combined_experiment(combo, :first_combo).configuration.combined).to eq([])
    end

    it 'duplicates the parent variants' do
      expect(described_class.combined_experiment(combo, :first_combo).configuration.variants.map(&:name)).to eq(combo.variants.map(&:name))
    end

    it 'duplicates the parent goals' do
      expect(described_class.combined_experiment(combo, :first_combo).configuration.goals.map(&:name)).to eq(combo.goals.map(&:name))
    end
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
    combined

    context 'when the combined experiment has been memoized' do
      subject { described_class.new([experiment], experiment.combined_experiments) }

      it 'does not call the class method' do
        expect(subject.class).to_not receive(:combined_experiment)
        subject.combined_experiment(experiment, :first)
      end

      it 'returns the experiment' do
        expect(subject.combined_experiment(experiment, :first)).to eq(experiment.combined_experiments.first)
      end
    end

    context 'when the combined experiment has not been memoized' do
      subject { described_class.new([experiment]) }

      it 'calls the class method' do
        expect(subject.class).to receive(:combined_experiment).with(experiment, :first)
        subject.combined_experiment(experiment, :first)
      end

      it 'memoizes the experiment' do
        expect { subject.combined_experiment(experiment, :first) }.to change { subject.instance_variable_get(:@combined) }
      end

      it 'returns the experiment' do
        expect(subject.combined_experiment(experiment, :first).experiment_name).to eq(:first)
      end
    end
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
    experiment(:foo) { |cfg| cfg.can_resume = true }
    experiment(:bar) { |cfg| cfg.can_resume = true }
    subject { described_class.new(experiments) }

    it_behaves_like 'a catalog enumerator'

    context 'when the experiments are both fresh' do
      it 'sorts experiments by their names' do
        expect(subject.by_started.to_a).to eq([bar, foo])
      end
    end

    context 'when one experiment is fresh' do
      before { bar.start! }

      it 'sorts fresh experiments above others' do
        expect(subject.by_started.to_a).to eq([foo, bar])
      end
    end

    context 'when the other experiment is fresh' do
      before { foo.start! }

      it 'sorts fresh experiments above others' do
        expect(subject.by_started.to_a).to eq([bar, foo])
      end
    end

    context 'when neither experiment is fresh' do
      before { experiments.each(&:start!) }

      context 'and both have a winner defined' do
        before { experiments.each { |exp| exp.declare_winner!(exp.variants.sample) } }

        it 'sorts experiments by their names' do
          expect(subject.by_started.to_a).to eq([bar, foo])
        end
      end

      context 'and one has a winner defined' do
        before { bar.declare_winner!(bar.variants.sample) }

        it 'sorts experiments with winners below others' do
          expect(subject.by_started.to_a).to eq([foo, bar])
        end
      end

      context 'and the other has a winner defined' do
        before { foo.declare_winner!(foo.variants.sample) }

        it 'sorts experiments with winners below others' do
          expect(subject.by_started.to_a).to eq([bar, foo])
        end
      end

      context 'and neither have a winner defined' do
        context 'and both are running' do
          before {
            TrailGuide.redis.hset(bar.storage_key, 'started_at', 1.hours.ago.to_i)
            TrailGuide.redis.hset(foo.storage_key, 'started_at', 2.hours.ago.to_i)
          }

          it 'sorts experiments by their started_at time ascending' do
            expect(subject.by_started.to_a).to eq([foo, bar])
          end

          context 'and their started_at time is equal' do
            before {
              start_time = 1.hour.ago.to_i
              TrailGuide.redis.hset(bar.storage_key, 'started_at', start_time)
              TrailGuide.redis.hset(foo.storage_key, 'started_at', start_time)
            }

            it 'sorts experiments by their names' do
              expect(subject.by_started.to_a).to eq([bar, foo])
            end
          end
        end

        context 'and one is running' do
          before { bar.stop! }

          it 'sorts running experiments above others' do
            expect(subject.by_started.to_a).to eq([foo, bar])
          end
        end

        context 'and the other is running' do
          before { foo.stop! }

          it 'sorts running experiments above others' do
            expect(subject.by_started.to_a).to eq([bar, foo])
          end
        end

        context 'and neither are running' do
          context 'and both are paused' do
            before {
              TrailGuide.redis.hset(bar.storage_key, 'started_at', 1.hours.ago.to_i)
              TrailGuide.redis.hset(bar.storage_key, 'paused_at',  20.minutes.ago.to_i)
              TrailGuide.redis.hset(foo.storage_key, 'started_at', 2.hours.ago.to_i)
              TrailGuide.redis.hset(foo.storage_key, 'paused_at',  30.minutes.ago.to_i)
            }

            it 'sorts experiments by their paused_at time ascending' do
              expect(subject.by_started.to_a).to eq([foo, bar])
            end

            context 'and their paused_at time is equal' do
              before {
                start_time = 1.hours.ago.to_i
                pause_time = 30.minutes.ago.to_i
                TrailGuide.redis.hset(bar.storage_key, 'started_at', start_time)
                TrailGuide.redis.hset(bar.storage_key, 'paused_at',  pause_time)
                TrailGuide.redis.hset(foo.storage_key, 'started_at', start_time)
                TrailGuide.redis.hset(foo.storage_key, 'paused_at',  pause_time)
              }

              it 'sorts experiments by their names' do
                expect(subject.by_started.to_a).to eq([bar, foo])
              end
            end
          end

          context 'and one is paused' do
            before {
              foo.pause!
              bar.stop!
            }

            it 'sorts paused experiments above others' do
              expect(subject.by_started.to_a).to eq([foo, bar])
            end
          end

          context 'and the other is paused' do
            before {
              bar.pause!
              foo.stop!
            }

            it 'sorts paused experiments above others' do
              expect(subject.by_started.to_a).to eq([bar, foo])
            end
          end

          context 'and neither is paused' do
            context 'and both are scheduled' do
              before {
                experiments.each(&:reset!)
                foo.schedule!(1.hours.from_now)
                bar.schedule!(2.hours.from_now)
              }

              it 'sorts experiments by their scheduled started_at time ascending' do
                expect(subject.by_started.to_a).to eq([foo, bar])
              end

              context 'and their scheduled started_at time is equal' do
                before {
                  start_time = 1.hour.from_now
                  experiments.each(&:reset!)
                  foo.schedule!(start_time)
                  bar.schedule!(start_time)
                }

                it 'sorts experiments by their names' do
                  expect(subject.by_started.to_a).to eq([bar, foo])
                end
              end
            end

            context 'and one is scheduled' do
              before {
                bar.stop!
                foo.reset!
                foo.schedule!(2.hours.from_now)
              }

              it 'sorts scheduled experiments above others' do
                expect(subject.by_started.to_a).to eq([foo, bar])
              end
            end

            context 'and the other is scheduled' do
              before {
                foo.stop!
                bar.reset!
                bar.schedule!(2.hours.from_now)
              }

              it 'sorts scheduled experiments above others' do
                expect(subject.by_started.to_a).to eq([bar, foo])
              end
            end

            context 'and neither is scheduled' do
              context 'and both are stopped' do
                before {
                  TrailGuide.redis.hset(bar.storage_key, 'started_at', 1.hours.ago.to_i)
                  TrailGuide.redis.hset(bar.storage_key, 'stopped_at',  20.minutes.ago.to_i)
                  TrailGuide.redis.hset(foo.storage_key, 'started_at', 2.hours.ago.to_i)
                  TrailGuide.redis.hset(foo.storage_key, 'stopped_at',  30.minutes.ago.to_i)
                }

                it 'sorts experiments by their stopped_at time ascending' do
                  expect(subject.by_started.to_a).to eq([foo, bar])
                end

                context 'and their stopped_at time is equal' do
                  before {
                    start_time = 1.hour.ago.to_i
                    stop_time = 30.minutes.ago.to_i
                    TrailGuide.redis.hset(bar.storage_key, 'started_at', start_time)
                    TrailGuide.redis.hset(bar.storage_key, 'stopped_at',  stop_time)
                    TrailGuide.redis.hset(foo.storage_key, 'started_at', start_time)
                    TrailGuide.redis.hset(foo.storage_key, 'stopped_at',  stop_time)
                  }

                  it 'sorts experiments by their names' do
                    expect(subject.by_started.to_a).to eq([bar, foo])
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  describe '#find' do
    experiment(:named)
    experiment(:unregistered)
    combined(:combo, combined: [:first_combo, :last_combo])
    experiment(:grouped, groups: [:first_group])
    subject { described_class.new([named, combo, grouped], combo.combined_experiments) }

    before do
      Object.send(:remove_const, :ClassyExperiment) if defined?(ClassyExperiment)
      ClassyExperiment = Class.new(TrailGuide::Experiment) do
        configure do |config|
          config.name = :classy
          variant :control
          variant :alternate
        end
      end
      subject.register(ClassyExperiment)
    end
    let(:classy) { ClassyExperiment }

    before do
      Object.send(:remove_const, :UnclassyExperiment) if defined?(UnclassyExperiment)
      UnclassyExperiment = Class.new(TrailGuide::Experiment) do
        configure do |config|
          config.name = :unclassy
          variant :control
          variant :alternate
        end
      end
    end
    let(:classy) { UnclassyExperiment }

    context 'when provided with an experiment class' do
      it 'returns the experiment' do
        expect(subject.find(ClassyExperiment)).to eq(ClassyExperiment)
      end

      context 'for an unregistered experiment' do
        it 'returns nil' do
          expect(subject.find(UnclassyExperiment)).to be_nil
        end
      end
    end

    context 'when provided with a symbol' do
      it 'returns the experiment' do
        expect(subject.find(:named)).to eq(named)
      end

      context 'for an unregistered experiment' do
        it 'returns nil' do
          expect(subject.find(:unregistered)).to be_nil
        end
      end

      context 'for a combined experiment' do
        it 'returns the experiment' do
          expect(subject.find(:first_combo)).to eq(combo.combined_experiments.find { |ce| ce.experiment_name == :first_combo })
        end
      end

      context 'for a group' do
        it 'returns the first experiment in that group' do
          expect(subject.find(:first_group)).to be < TrailGuide::Experiment
        end
      end
    end

    context 'when provided with a string' do
      it 'returns the experiment' do
        expect(subject.find('named')).to eq(named)
      end

      context 'for an unregistered experiment' do
        it 'returns nil' do
          expect(subject.find('unregistered')).to be_nil
        end
      end

      context 'for a combined experiment' do
        it 'returns the experiment' do
          expect(subject.find('first_combo')).to eq(combo.combined_experiments.find { |ce| ce.experiment_name == :first_combo })
        end
      end

      context 'for a group' do
        it 'returns the first experiment in that group' do
          expect(subject.find('first_group')).to be < TrailGuide::Experiment
        end
      end
    end
  end

  describe '#select' do
    experiment(:named)
    experiment(:other)
    experiment(:unregistered)
    combined(:combo, combined: [:first_combo, :last_combo])
    experiment(:grouped, groups: [:first_group])
    experiment(:also_grouped, groups: [:first_group])
    subject { described_class.new([named, other, combo, grouped, also_grouped], combo.combined_experiments) }

    before do
      Object.send(:remove_const, :ClassyExperiment) if defined?(ClassyExperiment)
      ClassyExperiment = Class.new(TrailGuide::Experiment) do
        configure do |config|
          config.name = :classy
          variant :control
          variant :alternate
        end
      end
      subject.register(ClassyExperiment)
    end
    let(:classy) { ClassyExperiment }

    before do
      Object.send(:remove_const, :UnclassyExperiment) if defined?(UnclassyExperiment)
      UnclassyExperiment = Class.new(TrailGuide::Experiment) do
        configure do |config|
          config.name = :unclassy
          variant :control
          variant :alternate
        end
      end
    end
    let(:classy) { UnclassyExperiment }

    it_behaves_like 'a catalog enumerator'

    context 'when provided with an experiment class' do
      it 'returns an array of matching experiments' do
        expect(subject.select(ClassyExperiment).to_a).to eq([ClassyExperiment])
      end

      context 'for an unregistered experiment' do
        it 'returns an empty array' do
          expect(subject.select(UnclassyExperiment).to_a).to eq([])
        end
      end
    end

    context 'when provided with a symbol' do
      it 'returns an array of matching experiments' do
        expect(subject.select(:named).to_a).to eq([named])
      end

      context 'for an unregistered experiment' do
        it 'returns an empty array' do
          expect(subject.select(:unregistered).to_a).to eq([])
        end
      end

      context 'for a combined experiment' do
        it 'returns an array of matching experiments' do
          expect(subject.select(:first_combo).to_a).to eq(combo.combined_experiments.select { |ce| ce.experiment_name == :first_combo })
        end
      end

      context 'for a group' do
        it 'returns an array of matching experiments' do
          expect(subject.select(:first_group).to_a).to eq([grouped, also_grouped])
        end
      end
    end

    context 'when provided with a string' do
      it 'returns an array of matching experiments' do
        expect(subject.select('named').to_a).to eq([named])
      end

      context 'for an unregistered experiment' do
        it 'returns an empty array' do
          expect(subject.select('unregistered').to_a).to eq([])
        end
      end

      context 'for a combined experiment' do
        it 'returns an array of matching experiments' do
          expect(subject.select('first_combo').to_a).to eq(combo.combined_experiments.select { |ce| ce.experiment_name == :first_combo })
        end
      end

      context 'for a group' do
        it 'returns an array of matching experiments' do
          expect(subject.select('first_group').to_a).to eq([grouped, also_grouped])
        end
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
    pending
  end

  describe '#import' do
    pending
  end

  describe '#missing' do
    experiment(:named)
    subject { described_class.new([named]) }
    before {
      named.save!
      TrailGuide.redis.hsetnx('not_exist', 'name', 'not_exist')
      TrailGuide.redis.set('unregistered:key', 'foobar')
    }

    it 'returns stored keys that do not match experiments in the catalog' do
      expect(subject.missing).to contain_exactly('not_exist', 'unregistered:key')
    end
  end

  describe '#orphaned' do
    it 'sets the provided orphan key as a list and adds the provided trace value' do
      expect(TrailGuide.redis).to receive(:sadd).with('orphans:testkey', 'dummy trace')
      subject.orphaned('testkey', 'dummy trace')
    end

    it 'sets the expiration of the key to 15 minutes' do
      expect(TrailGuide.redis).to receive(:expire).with('orphans:testkey', 15.minutes.seconds)
      subject.orphaned('testkey', 'dummy trace')
    end

    context 'when redis is unavailable' do
      before { allow(TrailGuide.redis).to receive(:sadd).and_raise(SocketError) }

      it 'returns false' do
        expect(subject.orphaned('testkey', 'dummy trace')).to be_falsey
      end
    end
  end

  describe '#orphans' do
    context 'when there are orphaned experiments or groups' do
      before {
        subject.orphaned('first', 'first orphan')
        subject.orphaned('first', 'also first')
        subject.orphaned('second', 'second orphan')
      }

      it 'returns all orphan keys as a hash' do
        expect(subject.orphans['first']).to contain_exactly('also first', 'first orphan')
        expect(subject.orphans['second']).to contain_exactly('second orphan')
      end
    end

    context 'when there are no orphaned experiments or groups' do
      it 'returns an empty hash' do
        expect(subject.orphans).to eq({})
      end
    end

    context 'when redis is unavailable' do
      before { allow(TrailGuide.redis).to receive(:keys).and_raise(SocketError) }

      it 'returns an empty hash' do
        expect(subject.orphans).to eq({})
      end
    end
  end

  describe '#adopted' do
    it 'deletes the provided key under the orphans namespace' do
      expect(TrailGuide.redis).to receive(:del).with('orphans:testkey')
      subject.adopted('testkey')
    end

    context 'when redis is unavailable' do
      before { allow(TrailGuide.redis).to receive(:del).and_raise(SocketError) }

      it 'returns false' do
        expect(subject.adopted('testkey')).to be_falsey
      end
    end
  end

  describe '#method_missing' do
    context 'when the experiments array responds to the method' do
      it 'proxies the method to the experiments array' do
        expect(subject.experiments).to receive(:slice).with(0,1)
        subject.slice(0,1)
      end
    end

    context 'when the experiments array does not respond to the method' do
      it 'raises a NoMethodError' do
        expect { subject.foobar }.to raise_exception(NoMethodError)
      end
    end
  end

  describe '#respond_to_missing?' do
    context 'when the experiments array responds to the method' do
      it 'returns true' do
        expect(subject.respond_to?(:slice)).to be_truthy
      end
    end

    context 'when the experiments array does not respond to the method' do
      it 'returns false' do
        expect(subject.respond_to?(:foobar)).to be_falsey
      end
    end
  end
end
