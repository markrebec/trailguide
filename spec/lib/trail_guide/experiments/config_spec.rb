require 'rails_helper'
require 'shared_examples/config'

RSpec.describe TrailGuide::Experiments::Config do
  experiment
  let(:config_hash) { {} }
  subject { described_class.new(experiment, **config_hash) }

  describe '#initialize' do
    it 'requires an experiment' do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    context 'when provided with options' do
      let(:config_hash) { { name: :foobar, summary: 'abcdefg' } }

      it 'merges options with defaults' do
        expect(subject.to_h.keys).to eq(described_class::DEFAULT_KEYS + described_class::CALLBACK_KEYS)
        expect(subject.name).to eq(:foobar)
        expect(subject.summary).to eq('abcdefg')
      end
    end

    context 'when inheriting from an ancestor' do
      let(:ancestor) { described_class.new(experiment, name: 'ancestor', foo: 'foobar', bar: 'bazqux', on_start: -> { nil }) }
      let(:config_hash) { { inherit: ancestor } }

      it 'clears the inherit option' do
        expect(subject.to_h.keys).to_not include(:inherit)
      end

      it 'slices valid options based on provided args and default keys' do
        custom = described_class.new(experiment, :foo, :bar, **config_hash)
        expect(custom.foo).to eq('foobar')
        expect(custom.bar).to eq('bazqux')
      end

      it 'clears the ancestor name' do
        expect(subject.name).to be_nil
      end

      it 'duplicates the ancestor goals' do
        expect(subject.goals).to eq(ancestor.goals)
      end

      it 'duplicates the ancestor combined' do
        expect(subject.combined).to eq(ancestor.combined)
      end

      it 'duplicates the ancestor variants' do
        expect(subject.variants.to_a).to eq(ancestor.variants.to_a)
      end

      it 'merges the ancestor callbacks into the options' do
        expect(subject.callbacks).to eq(ancestor.callbacks)
      end
    end
  end

  describe '#start_manually?' do
    it_behaves_like 'a boolean config method', :start_manually
  end

  describe '#reset_manually?' do
    it_behaves_like 'a boolean config method', :reset_manually
  end

  describe '#sticky_assignment?' do
    it_behaves_like 'a boolean config method', :sticky_assignment
  end

  describe '#allow_multiple_conversions?' do
    it_behaves_like 'a boolean config method', :allow_multiple_conversions
  end

  describe '#allow_multiple_goals?' do
    it_behaves_like 'a boolean config method', :allow_multiple_goals
  end

  describe '#track_winner_conversions?' do
    it_behaves_like 'a boolean config method', :track_winner_conversions
  end

  describe '#skip_request_filter?' do
    it_behaves_like 'a boolean config method', :skip_request_filter
  end

  describe '#can_resume?' do
    it_behaves_like 'a boolean config method', :can_resume
  end

  describe '#enable_calibration?' do
    it_behaves_like 'a boolean config method', :enable_calibration
  end

  describe '#preview_url?' do
    it_behaves_like 'a boolean config method', :preview_url

    context 'when configured with a value' do
      before { subject.preview_url = 'www.example.com/foobar' }

      it 'returns true' do
        expect(subject.preview_url?).to eq(true)
      end
    end
  end

  describe '#name' do
    context 'when configured with a name' do
      before { subject.name = 'TestName' }

      it 'underscores and converts the name to a symbol' do
        expect(subject.name).to eq(:test_name)
      end
    end

    context 'when not configured with a name' do
      context 'with a custom experiment class' do
        before do
          Object.send(:remove_const, :ClassyExperiment) if defined?(ClassyExperiment)
          ClassyExperiment = Class.new(TrailGuide::Experiment) do
            configure do |config|
              config.name = :classy
              variant :control
              variant :alternate
            end
          end
        end

        it 'underscores and converts the experiment class name to a symbol' do
          expect(described_class.new(ClassyExperiment).name).to eq(:classy_experiment)
        end
      end

      it 'returns an empty string' do
        expect(subject.name).to be_blank
      end
    end
  end

  describe '#algorithm' do
    before { subject.algorithm = :random }

    it 'maps the configured algorithm to the algorithm class' do
      expect(subject.algorithm).to eq(TrailGuide::Algorithms::Random)
    end

    it 'calls TrailGuide::Algorithms.algorithm' do
      expect(TrailGuide::Algorithms).to receive(:algorithm).with(:random)
      subject.algorithm
    end

    context 'when configured with an array' do
      let(:blk) { -> (var,mtd) { return true } }
      before { subject.algorithm = :static, blk }

      it 'maps the configured algorithm to the algorithm class' do
        expect(subject.algorithm).to be_a(TrailGuide::Algorithms::Static)
      end

      it 'passes the last argument as a block' do
        expect(TrailGuide::Algorithms::Static).to receive(:new).with(no_args) { |&block| expect(blk).to be(block) }
        subject.algorithm
      end

      it 'calls TrailGuide::Algorithms.algorithm' do
        expect(TrailGuide::Algorithms).to receive(:algorithm).with(:static).and_call_original
        subject.algorithm
      end
    end
  end

  describe '#variants' do
    before {
      subject.configure {
        variant :control
        variant :alternate
      }
    }
    variant(:control)
    variant(:alternate)

    it 'returns a variant collection' do
      expect(subject.variants).to be_a(TrailGuide::Variants)
    end

    it 'contains the experiment variants' do
      expect(subject.variants.to_a).to contain_exactly(control, alternate)
    end
  end

  describe '#variant' do
    context 'when the variant does not exist' do
      before {
        subject.configure {
          variant :control
          variant :alternate
        }
      }
      variant(:control)
      variant(:alternate)

      it 'adds the variant to the experiment' do
        subject.variant(:foobar)
        expect(subject.variants.map(&:name)).to include(:foobar)
      end

      context 'when the control flag is true' do
        it 'adds the variant as the control' do
          subject.variant(:foobar, control: true)
          expect(subject.variants.last.control?).to be_truthy
        end

        it 'removes the existing control variant' do
          subject.variant(:foobar, control: true)
          expect(subject.variants.map(&:control?).count { |c| c === true }).to eq(1)
        end
      end
    end

    context 'when no variants exist' do
      it 'sets the first variant as the control' do
        subject.variant(:foobar)
        expect(subject.variants.last.control?).to be_truthy
      end
    end

  end

  describe '#control' do
    before {
      subject.configure {
        variant :first
        variant :last
      }
    }

    context 'when a control has been set' do
      it 'returns the control' do
        expect(subject.control.name).to eq(:first)
      end
    end

    context 'when no control has been set' do
      before {
        subject[:variants].each(&:variant!)
      }

      it 'returns the first variant' do
        expect(subject.control.name).to eq(:first)
      end
    end
  end

  describe '#control=' do
    before {
      subject.configure {
        variant :first
        variant :second
      }
    }

    it 'resets all variants' do
      subject.variants.each { |v| expect(v).to receive(:variant!) }
      subject.control = :first
    end

    it 'returns the variant' do
      expect(subject.send(:control=, :first).name).to eq(:first)
    end

    context 'when the variant exists' do
      it 'flags the variant as the control' do
        subject.control = :second
        expect(subject.control.name).to eq(:second)
      end
    end

    context 'when the variant does not exist' do
      it 'adds the variant' do
        expect { subject.control = :third }.to change { subject.variants.count }.from(2).to(3)
      end

      it 'flags the variant as the control' do
        subject.control = :third
        expect(subject.control.name).to eq(:third)
      end
    end
  end

  describe '#group' do
    before { subject[:groups] = [:first, :second] }

    context 'without an argument' do
      it 'returns the first group' do
        expect(subject.group).to eq(:first)
      end
    end

    context 'with an argument' do
      it 'adds the group' do
        expect { subject.group(:third) }.to change { subject.groups }.from([:first, :second]).to([:first, :second, :third])
      end

      it 'returns the group' do
        expect(subject.group(:third)).to eq(:third)
      end
    end
  end

  describe '#group=' do
    before { subject[:groups] = [:first, :second] }

    it 'adds the group to the front of the list' do
      expect { subject.group = :third }.to change { subject.groups }.from([:first, :second]).to([:third, :first, :second])
    end

    it 'returns the group' do
      expect(subject.send(:group=, :third)).to eq(:third)
    end
  end

  describe '#groups' do
    before { subject[:groups] = [:first, :second] }

    context 'without any arguments' do
      it 'returns the array of groups' do
        expect(subject.groups).to eq([:first, :second])
      end
    end

    context 'with group arguments' do
      it 'adds the groups to the list' do
        expect { subject.groups(:third, :last) }.to change { subject.groups }.from([:first, :second]).to([:first, :second, :third, :last])
      end

      it 'returns the array of groups' do
        expect(subject.groups(:third, :last)).to eq([:first, :second, :third, :last])
      end
    end
  end

  describe '#groups=' do
    it 'sets the list of groups' do
      expect { subject.groups = :first, :second }.to change { subject.groups }.from([]).to([:first, :second])
    end

    context 'when groups have been set' do
      before { subject[:groups] = [:first, :second] }

      it 'clears the existing groups' do
        expect { subject.groups = :third, :last }.to change { subject.groups }.from([:first, :second]).to([:third, :last])
      end
    end
  end

  describe '#goal' do
    let(:cfg) { {} }
    let(:blk) { Proc.new {} }

    it 'creates a new goal with the provided arguments' do
      expect(TrailGuide::Metrics::Goal).to receive(:new).with(subject.experiment, :foobar, **cfg, &blk)
      subject.goal(:foobar, **cfg, &blk)
    end

    it 'adds the goal to the list of goals' do
      expect { subject.goal(:foobar, **cfg, &blk) }.to change { subject.goals }
    end
  end

  describe '#goal=' do
    it 'creates a new goal with the provided arguments' do
      expect(TrailGuide::Metrics::Goal).to receive(:new).with(subject.experiment, :foobar)
      subject.goal = :foobar
    end

    it 'adds the goal to the list of goals' do
      expect { subject.goal = :foobar }.to change { subject.goals }
    end
  end

  describe '#goals' do
    before { subject.goals = :foo, :bar }

    context 'without any arguments' do
      it 'returns the array of goals' do
        expect(subject.goals.map(&:name)).to eq([:foo, :bar])
      end
    end

    context 'with goal arguments' do
      it 'adds the goals to the list' do
        expect { subject.goals(:third, :last) }.to change { subject.goals.map(&:name) }.from([:foo, :bar]).to([:foo, :bar, :third, :last])
      end

      it 'returns the array of goals' do
        expect(subject.goals(:third, :last).map(&:name)).to eq([:foo, :bar, :third, :last])
      end
    end
  end

  describe '#goals=' do
    it 'creates new goals with the provided names' do
      expect(TrailGuide::Metrics::Goal).to receive(:new).with(subject.experiment, :foo)
      expect(TrailGuide::Metrics::Goal).to receive(:new).with(subject.experiment, :bar)
      subject.goals = :foo, :bar
    end

    it 'sets the list of goals' do
      expect { subject.goals = :foo, :bar }.to change { subject.goals }
    end

    context 'when goals have been set' do
      before { subject.goal(:foo) }

      it 'clears the existing groups' do
        expect { subject.goals = :bar, :baz }.to change { subject.goals.map(&:name) }.from([:foo]).to([:bar, :baz])
      end
    end
  end

  describe '#metric' do
    let(:cfg) { {} }
    let(:blk) { Proc.new {} }

    it 'calls group with the name' do
      expect(subject).to receive(:group).with(:foobar)
      subject.metric(:foobar, **cfg, &blk)
    end

    it 'calls goal with the arguments' do
      expect(subject).to receive(:goal).with(:foobar, **cfg, &blk)
      subject.metric(:foobar, **cfg, &blk)
    end
  end

  describe '#metric=' do
    it 'calls group with the name' do
      expect(subject).to receive(:group=).with(:foobar)
      subject.metric = :foobar
    end

    it 'calls goal with the arguments' do
      expect(subject).to receive(:goal=).with(:foobar)
      subject.metric = :foobar
    end
  end

  describe '#metrics' do
    let(:cfg) { {} }
    let(:blk) { Proc.new {} }

    it 'calls groups with the names' do
      expect(subject).to receive(:groups).with(:foo, :bar)
      subject.metrics(:foo, :bar, **cfg, &blk)
    end

    it 'calls goals with the arguments' do
      expect(subject).to receive(:goals).with(:foo, :bar, **cfg, &blk)
      subject.metrics(:foo, :bar, **cfg, &blk)
    end
  end

  describe '#metrics=' do
    it 'calls groups with the names' do
      expect(subject).to receive(:groups=).with(:foo, :bar)
      subject.metrics = :foo, :bar
    end

    it 'calls goals with the arguments' do
      expect(subject).to receive(:goals=).with(:foo, :bar)
      subject.metrics = :foo, :bar
    end
  end

  describe '#combined' do
    before { subject.combined = [:combo] }

    it 'returns the array of variants' do
      expect(subject.combined).to eq([:combo])
    end
  end

  describe '#combined?' do
    context 'when not configured as a combined experiment' do
      it 'returns false' do
        expect(subject.combined?).to be(false)
      end
    end

    context 'when configured as a combined experiment' do
      before { subject.combined = [:combo] }

      it 'returns true' do
        expect(subject.combined?).to be(true)
      end
    end
  end

  describe '#callbacks' do
    it 'returns a hash of callbacks' do
      expect(subject.callbacks).to eq({
        on_choose: [],
        on_use: [],
        on_convert: [],
        on_start: [],
        on_schedule: [],
        on_stop: [],
        on_pause: [],
        on_resume: [],
        on_winner: [],
        on_reset: [],
        on_delete: [],
        on_redis_failover: [],
        allow_participation: [],
        allow_conversion: [],
        track_participation: [],
        rollout_winner: [],
      })
    end
  end

  describe '#on_choose' do
    it_behaves_like 'a callback config method', :on_choose
  end

  describe '#on_use' do
    it_behaves_like 'a callback config method', :on_use
  end

  describe '#on_convert' do
    it_behaves_like 'a callback config method', :on_convert
  end

  describe '#on_start' do
    it_behaves_like 'a callback config method', :on_start
  end

  describe '#on_schedule' do
    it_behaves_like 'a callback config method', :on_schedule
  end

  describe '#on_stop' do
    it_behaves_like 'a callback config method', :on_stop
  end

  describe '#on_pause' do
    it_behaves_like 'a callback config method', :on_pause
  end

  describe '#on_resume' do
    it_behaves_like 'a callback config method', :on_resume
  end

  describe '#on_winner' do
    it_behaves_like 'a callback config method', :on_winner
  end

  describe '#on_reset' do
    it_behaves_like 'a callback config method', :on_reset
  end

  describe '#on_delete' do
    it_behaves_like 'a callback config method', :on_delete
  end

  describe '#on_redis_failover' do
    it_behaves_like 'a callback config method', :on_redis_failover
  end

  describe '#allow_participation' do
    it_behaves_like 'a callback config method', :allow_participation
  end

  describe '#allow_conversion' do
    it_behaves_like 'a callback config method', :allow_conversion
  end

  describe '#track_participation' do
    it_behaves_like 'a callback config method', :track_participation
  end

  describe '#rollout_winner' do
    it_behaves_like 'a callback config method', :rollout_winner
  end
end
