require 'rails_helper'

RSpec.describe TrailGuide::Helper::ExperimentProxy do
  participant
  experiment
  variant(:control)
  variant(:alternate)
  let(:context) { Class.new { include TrailGuide::Helper }.new }
  let(:expkey) { experiment.experiment_name }
  subject { described_class.new(context, expkey, participant: participant) }

  describe '#choose!' do
    before { allow_any_instance_of(experiment).to receive(:choose!).and_return(control) }

    context 'when referencing an experiment that does not exist' do
      let(:expkey) { :foobar }

      it 'raises a NoExperimentsError' do
        expect { subject.choose! }.to raise_exception(TrailGuide::NoExperimentsError)
      end
    end

    context 'when referencing a group' do
      experiment { groups :foobar }
      experiment { groups :foobar }
      let(:expkey) { :foobar }

      it 'raises a TooManyExperimentsError' do
        expect { subject.choose! }.to raise_exception(TrailGuide::TooManyExperimentsError)
      end
    end

    context 'when referencing a combined experiment' do
      combined

      it 'raises a TooManyExperimentsError' do
        expect { subject.choose! }.to raise_exception(TrailGuide::TooManyExperimentsError)
      end
    end

    context 'when referencing an experiment' do
      let(:metadata) { {baz: :qux} }

      it 'calls choose! on the experiment' do
        expect(subject.experiment).to receive(:choose!)
        subject.choose!
      end

      it 'passes the provided options through when choosing' do
        expect(subject.experiment).to receive(:choose!).with(override: :foo, excluded: :bar, metadata: metadata)
        subject.choose!(override: :foo, excluded: :bar, metadata: metadata)
      end

      it 'sets a default for the override option' do
        expect(subject).to receive(:override_variant).and_return(nil).ordered
        expect(subject.experiment).to receive(:choose!).with(override: nil, excluded: false).ordered
        subject.choose!
      end

      it 'sets a default for the excluded option' do
        expect(subject).to receive(:exclude_visitor?).and_return(false).ordered
        expect(subject.experiment).to receive(:choose!).with(override: nil, excluded: false).ordered
        subject.choose!
      end

      it 'returns the chosen variant' do
        expect(subject.choose!).to be(control)
      end

      context 'when given a block' do
        it 'yields the variant and metadata to the block' do
          expect { |b| subject.choose!(metadata: metadata, &b) }.to yield_with_args(control, metadata)
        end
      end
    end
  end

  describe '#choose' do
    before { allow_any_instance_of(experiment).to receive(:choose!).and_return(control) }
    let(:metadata) { {foo: :bar} }
    let(:block) { -> (var,mtd) { } }

    it 'calls choose! with the provided arguments' do
      expect(subject).to receive(:choose!).with(metadata: metadata) { |&blk| expect(blk).to be(block) }
      subject.choose(metadata: metadata, &block)
    end

    context 'when referencing an experiment that does not exist' do
      let(:expkey) { :foobar }

      it 'raises a NoExperimentsError' do
        expect { subject.choose }.to raise_exception(TrailGuide::NoExperimentsError)
      end
    end

    context 'when referencing a group' do
      experiment { groups :foobar }
      experiment { groups :foobar }
      let(:expkey) { :foobar }

      it 'logs the error' do
        expect(TrailGuide.logger).to receive(:error).with(an_instance_of(TrailGuide::TooManyExperimentsError))
        subject.choose
      end

      it 'returns first experiment control' do
        expect(subject.choose).to be(subject.experiment.control)
      end
    end

    context 'when referencing a combined experiment' do
      combined

      it 'logs the error' do
        expect(TrailGuide.logger).to receive(:error).with(an_instance_of(TrailGuide::TooManyExperimentsError))
        subject.choose
      end

      it 'returns first experiment control' do
        expect(subject.choose).to be(subject.experiment.control)
      end
    end
  end

  describe '#run!' do
    before { allow_any_instance_of(experiment).to receive(:choose!).and_return(control) }
    let(:metadata) { {foo: :bar} }

    it 'calls choose! with the provided arguments' do
      expect(subject).to receive(:choose!).with(metadata: metadata)
      subject.run!(metadata: metadata)
    end

    context 'when referencing an experiment that does not exist' do
      let(:expkey) { :foobar }

      it 'raises a NoExperimentsError' do
        expect { subject.run! }.to raise_exception(TrailGuide::NoExperimentsError)
      end
    end

    context 'when referencing a group' do
      experiment { groups :foobar }
      experiment { groups :foobar }
      let(:expkey) { :foobar }

      it 'raises a TooManyExperimentsError' do
        expect { subject.run! }.to raise_exception(TrailGuide::TooManyExperimentsError)
      end
    end

    context 'when referencing a combined experiment' do
      combined

      it 'raises a TooManyExperimentsError' do
        expect { subject.run! }.to raise_exception(TrailGuide::TooManyExperimentsError)
      end
    end

    context 'when the context does not respond to the variant method' do
      it 'raises a NoVariantMethodError' do
        expect { subject.run! }.to raise_exception(TrailGuide::NoVariantMethodError)
      end
    end

    context 'when the context responds to the variant method' do
      let(:context) {
        Class.new {
          include TrailGuide::Helper

          def control
            proxied
          end

          def proxied(*args)
          end
        }.new
      }

      it 'calls the variant method' do
        expect(context).to receive(:proxied)
        subject.run!
      end

      context 'and the variant method does not accept any arguments' do
        it 'calls the variant method without any arguments' do
          expect(context).to receive(:proxied).with(no_args)
          subject.run!
        end
      end

      context 'and the variant method accepts a single argument' do
        let(:context) {
          Class.new {
            include TrailGuide::Helper

            def control(metadata)
              proxied(metadata)
            end

            def proxied(*args)
            end
          }.new
        }

        it 'calls the variant method with the variant metadata' do
          expect(context).to receive(:proxied).with(control.metadata)
          subject.run!
        end
      end

      context 'and the variant method accepts multiple arguments' do
        let(:context) {
          Class.new {
            include TrailGuide::Helper

            def control(variant, metadata)
            end
          }.new
        }

        it 'calls the variant method with the variant and the metadata' do
          expect(context).to receive(:control).with(control, control.metadata)
          subject.run!
        end
      end
    end

    context 'when provided with a methods argument' do
      let(:context) {
        Class.new {
          include TrailGuide::Helper

          def varmeth(variant, metadata)
          end
        }.new
      }

      it 'uses the provided method instead of the variant name' do
        expect(context).to receive(:varmeth).with(control, control.metadata)
        subject.run!(methods: {control: :varmeth})
      end
    end
  end

  describe '#run' do
    before { allow_any_instance_of(experiment).to receive(:choose!).and_return(control) }
    let(:metadata) { {foo: :bar} }

    it 'calls run! with the provided arguments' do
      expect(subject).to receive(:run!).with(methods: {control: :foobar}, metadata: metadata)
      subject.run(methods: {control: :foobar}, metadata: metadata)
    end

    context 'when referencing an experiment that does not exist' do
      let(:expkey) { :foobar }

      it 'raises a NoExperimentsError' do
        expect { subject.run }.to raise_exception(TrailGuide::NoExperimentsError)
      end
    end

    context 'when referencing a group' do
      experiment { groups :foobar }
      experiment { groups :foobar }
      let(:expkey) { :foobar }

      it 'logs the error' do
        expect(TrailGuide.logger).to receive(:error).with(an_instance_of(TrailGuide::TooManyExperimentsError))
        subject.run
      end

      it 'returns false' do
        expect(subject.run).to be_falsey
      end
    end

    context 'when referencing a combined experiment' do
      combined

      it 'logs the error' do
        expect(TrailGuide.logger).to receive(:error).with(an_instance_of(TrailGuide::TooManyExperimentsError))
        subject.run
      end

      it 'returns false' do
        expect(subject.run).to be_falsey
      end
    end
  end

  describe '#render!' do
    before { allow_any_instance_of(experiment).to receive(:choose!).and_return(control) }
    let(:metadata) { {foo: :bar} }
    let(:context) {
      Class.new {
        include TrailGuide::Helper

        def render(*args, &block)
        end
      }.new
    }

    it 'calls choose! with the provided arguments' do
      expect(subject).to receive(:choose!).with(metadata: metadata)
      subject.render!(metadata: metadata)
    end

    context 'when referencing an experiment that does not exist' do
      let(:expkey) { :foobar }

      it 'raises a NoExperimentsError' do
        expect { subject.render! }.to raise_exception(TrailGuide::NoExperimentsError)
      end
    end

    context 'when referencing a group' do
      experiment { groups :foobar }
      experiment { groups :foobar }
      let(:expkey) { :foobar }

      it 'raises a TooManyExperimentsError' do
        expect { subject.render! }.to raise_exception(TrailGuide::TooManyExperimentsError)
      end
    end

    context 'when referencing a combined experiment' do
      combined

      it 'raises a TooManyExperimentsError' do
        expect { subject.render! }.to raise_exception(TrailGuide::TooManyExperimentsError)
      end
    end

    context 'when the context does not support rendering' do
      let(:context) { Class.new { include TrailGuide::Helper }.new }

      it 'raises an UnsupportedContextError' do
        expect { subject.render! }.to raise_exception(TrailGuide::UnsupportedContextError)
      end
    end

    context 'when the context supports rendering' do
      it 'calls the context render method' do
        expect(context).to receive(:render)
        subject.render!
      end

      context 'when provided with local variables' do
        it 'passes the locals through when rendering' do
          expect(context).to receive(:render).with("#{experiment.experiment_name}/control", foo: :bar, metadata: {}, variant: control)
          subject.render!(locals: {foo: :bar})
        end
      end

      context 'when provided with templates' do
        it 'renders the matching template instead of the variant name' do
          expect(context).to receive(:render).with('template_path', metadata: {}, variant: control)
          subject.render!(templates: {control: 'template_path'})
        end
      end

      context 'when provided with a prefix' do
        it 'uses the prefix when generating template paths' do
          expect(context).to receive(:render).with("foobar/#{experiment.experiment_name}/control", metadata: {}, variant: control)
          subject.render!(prefix: 'foobar/')
        end
      end

      context 'when the context provides a rails template lookup_context' do
        let(:context) {
          Class.new {
            include TrailGuide::Helper

            def render(*args, &block)
            end

            def lookup_context
              Struct.new(:prefixes).new(['first', 'last'])
            end
          }.new
        }

        it 'uses the first prefix in the list' do
          expect(context).to receive(:render).with("first/#{experiment.experiment_name}/control", metadata: {}, variant: control)
          subject.render!
        end
      end

      context 'when the context provides a rails view_context' do
        let(:context) {
          Class.new {
            include TrailGuide::Helper

            def render(*args, &block)
            end

            def view_context
              Struct.new(:lookup_context).new(Struct.new(:prefixes).new(['first', 'last']))
            end
          }.new
        }

        it 'uses the first prefix in the list' do
          expect(context).to receive(:render).with("first/#{experiment.experiment_name}/control", metadata: {}, variant: control)
          subject.render!
        end
      end

      context 'when the context does not provide a lookup_context' do
        it 'uses an empty/relative path' do
          expect(context).to receive(:render).with("#{experiment.experiment_name}/control", metadata: {}, variant: control)
          subject.render!
        end
      end
    end
  end

  describe '#render' do
    before { allow_any_instance_of(experiment).to receive(:choose!).and_return(control) }
    let(:metadata) { {foo: :bar} }
    let(:prefix) { :foobar }
    let(:templates) { {control: :foobar} }
    let(:locals) { {baz: :qux} }
    let(:context) {
      Class.new {
        include TrailGuide::Helper

        def render(*args, &block)
        end
      }.new
    }

    it 'calls render! with the provided arguments' do
      expect(subject).to receive(:render!).with(prefix: prefix, templates: templates, locals: locals, metadata: metadata)
      subject.render(prefix: prefix, templates: templates, locals: locals, metadata: metadata)
    end

    context 'when referencing an experiment that does not exist' do
      let(:expkey) { :foobar }

      it 'raises a NoExperimentsError' do
        expect { subject.render }.to raise_exception(TrailGuide::NoExperimentsError)
      end
    end

    context 'when referencing a group' do
      experiment { groups :foobar }
      experiment { groups :foobar }
      let(:expkey) { :foobar }

      it 'logs the error' do
        expect(TrailGuide.logger).to receive(:error).with(an_instance_of(TrailGuide::TooManyExperimentsError))
        subject.render
      end

      it 'returns false' do
        expect(subject.render).to be_falsey
      end
    end

    context 'when referencing a combined experiment' do
      combined

      it 'logs the error' do
        expect(TrailGuide.logger).to receive(:error).with(an_instance_of(TrailGuide::TooManyExperimentsError))
        subject.render
      end

      it 'returns false' do
        expect(subject.render).to be_falsey
      end
    end
  end

  describe '#convert!' do
    before { allow_any_instance_of(experiment).to receive(:convert!).and_return(control) }
    let(:metadata) { {foo: :bar} }

    context 'when referencing an experiment that does not exist' do
      let(:expkey) { :foobar }

      it 'tracks the orphaned experiment' do
        expect(TrailGuide.catalog).to receive(:orphaned).with(expkey, kind_of(String))
        subject.convert!
      end

      it 'returns false' do
        expect(subject.convert!).to be_falsey
      end

      context 'when ignoring orphaned experiments' do
        before { TrailGuide.configuration.ignore_orphaned_groups = true }
        after  { TrailGuide.configuration.ignore_orphaned_groups = false }

        it 'does not track the orphaned experiment' do
          expect(TrailGuide.catalog).to_not receive(:orphaned)
          subject.convert!
        end
      end
    end

    context 'when referencing a group' do
      experiment { groups :foobar }
      experiment { groups :foobar }
      let(:expkey) { :foobar }

      it 'converts all matching experiments' do
        subject.experiments.each { |exp| expect(exp).to receive(:convert!) }
        subject.convert!
      end

      it 'returns an array of results' do
        subject.experiments.each { |exp| allow(exp).to receive(:convert!).and_return(control) }
        expect(subject.convert!).to eq([control, control])
      end

      context 'when none of the experiments convert' do
        it 'returns false' do
          subject.experiments.each { |exp| allow(exp).to receive(:convert!).and_return(false) }
          expect(subject.convert!).to be_falsey
        end
      end
    end

    context 'when referencing a combined experiment' do
      combined

      # TODO should this actually fail? should you be able to convert all combined at once?
      it 'converts all matching experiments' do
        subject.experiment.combined_experiments.each { |exp| expect(exp).to receive(:convert!) }
        subject.convert!
      end

      it 'returns an array of results' do
        subject.experiment.combined_experiments.each { |exp| allow(exp).to receive(:convert!).and_return(control) }
        expect(subject.convert!).to eq([control, control])
      end

      context 'when none of the experiments convert' do
        it 'returns false' do
          subject.experiment.combined_experiments.each { |exp| allow(exp).to receive(:convert!).and_return(false) }
          expect(subject.convert!).to be_falsey
        end
      end
    end

    context 'when referencing an experiment' do
      it 'calls convert! on the experiment' do
        expect(subject.experiment).to receive(:convert!)
        subject.convert!
      end

      it 'passes the provided options through when converting' do
        expect(subject.experiment).to receive(:convert!).with(:foobar, metadata: metadata)
        subject.convert!(:foobar, metadata: metadata)
      end

      context 'when conversion is successful' do
        it 'returns an array of results' do
          expect(subject.convert!).to eq([control])
        end
      end

      context 'when the experiment does not convert' do
        it 'returns false' do
          allow(subject.experiment).to receive(:convert!).and_return(false)
          expect(subject.convert!).to be_falsey
        end
      end

      context 'when given a block' do
        it 'yields the results and metadata to the block' do
          expect { |b| subject.convert!(metadata: metadata, &b) }.to yield_with_args([control], metadata)
        end
      end
    end

  end

  describe '#convert' do
    before { allow_any_instance_of(experiment).to receive(:convert!).and_return(control) }
    let(:metadata) { {foo: :bar} }
    let(:block) { -> (var,mtd) { } }

    it 'calls convert! with the provided arguments' do
      expect(subject).to receive(:convert!).with(:foobar, metadata: metadata) { |&blk| expect(blk).to be(block) }
      subject.convert(:foobar, metadata: metadata, &block)
    end
  end

  describe '#experiments' do
    context 'when referencing a group' do
      experiment { groups :foobar }
      experiment { groups :foobar }
      let(:expkey) { :foobar }

      it 'returns all matching experiments in the catalog' do
        expect(subject.experiments.map(&:class)).to contain_exactly(*experiments.last(2))
      end

      it 'initializes trials for each experiment' do
        subject.experiments.each do |trial|
          expect(trial.class).to be < TrailGuide::Experiment
        end
      end
    end

    context 'when referencing a single experiment' do
      it 'returns an array with the single experiment' do
        expect(subject.experiments.map(&:class)).to eq([experiment])
      end

      it 'initializes a trial for the experiment' do
        subject.experiments.each do |trial|
          expect(trial.class).to be < TrailGuide::Experiment
        end
      end
    end
  end

  describe '#experiment' do
    it 'calls experiments' do
      expect(subject).to receive(:experiments).and_return([])
      subject.experiment
    end

    context 'when referencing a group' do
      experiment { groups :foobar }
      experiment { groups :foobar }
      let(:expkey) { :foobar }

      it 'returns the first experiment in the group' do
        expect(subject.experiment).to be(subject.experiments.first)
      end
    end

    context 'when referencing a single experiment' do
      it 'returns the experiment' do
        expect(subject.experiment).to be_an_instance_of(experiment)
      end
    end
  end

  describe '#override_variant' do
    context 'when the context does not support params' do
      it 'returns nil' do
        expect(subject.override_variant).to be_nil
      end
    end

    context 'when no override param is present' do
      let(:context) {
        Class.new {
          include TrailGuide::Helper

          def params
            {}
          end
        }.new
      }

      it 'returns nil' do
        expect(subject.override_variant).to be_nil
      end
    end

    context 'when the experiment is not included in the override param' do
      let(:context) {
        Class.new {
          include TrailGuide::Helper

          def params
            {TrailGuide.configuration.override_parameter => {}}
          end
        }.new
      }

      it 'returns nil' do
        expect(subject.override_variant).to be_nil
      end
    end

    context 'when the override variant does not exist' do
      experiment(:override_exp)
      let(:context) {
        Class.new {
          include TrailGuide::Helper

          def params
            {TrailGuide.configuration.override_parameter => {'override_exp' => 'foobar'}}
          end
        }.new
      }

      it 'returns nil' do
        expect(subject.override_variant).to be_nil
      end
    end

    context 'when the override variant exists in the experiment' do
      experiment(:override_exp)
      let(:context) {
        Class.new {
          include TrailGuide::Helper

          def params
            {TrailGuide.configuration.override_parameter => {'override_exp' => 'control'}}
          end
        }.new
      }

      it 'returns the variant name' do
        expect(subject.override_variant).to be(:control)
      end
    end
  end

  describe '#exclude_visitor?' do
    it 'calls trailguide_excluded_request? on the context' do
      expect(context).to receive(:trailguide_excluded_request?)
      subject.exclude_visitor?
    end

    context 'when configured to skip request filtering' do
      experiment { |cfg| cfg.skip_request_filter = true }

      it 'returns false' do
        expect(subject.exclude_visitor?).to be_falsey
      end
    end
  end
end
