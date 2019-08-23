require 'rails_helper'

RSpec.describe TrailGuide::Helper::HelperProxy do
  experiment
  participant
  variant(:control)
  let(:context) { Class.new { include TrailGuide::Helper }.new }
  let(:expkey) { experiment.experiment_name }
  let(:exproxy) { TrailGuide::Helper::ExperimentProxy.new(context, expkey, participant: participant) }
  subject { described_class.new(context, participant: participant) }

  describe '#initialize' do
    it 'memoizes the @context' do
      expect(subject.instance_variable_get(:@context)).to be(context)
    end

    context 'when a participant is provided' do
      it 'memoizes the @participant' do
        expect(subject.instance_variable_get(:@participant)).to be(participant)
      end
    end
  end

  describe '#new' do
    it 'returns an ExperimentProxy for the provided key' do
      expect(subject.new(expkey)).to be_a(TrailGuide::Helper::ExperimentProxy)
      expect(subject.new(expkey).experiment).to be_a(experiment)
    end
  end

  describe '#choose!' do
    it 'initializes an ExperimentProxy for the provided key' do
      expect(subject).to receive(:new).with(expkey).and_call_original
      subject.choose!(expkey)
    end

    it 'calls choose! on the ExperimentProxy with the provided arguments' do
      allow(subject).to receive(:new).and_return(exproxy)
      expect(exproxy).to receive(:choose!).with(foo: :bar)
      subject.choose!(expkey, foo: :bar)
    end
  end

  describe '#choose' do
    before {
      allow(subject).to receive(:new).and_return(exproxy)
      allow(exproxy).to receive(:choose!).and_return(control)
    }

    it 'initializes an ExperimentProxy for the provided key' do
      expect(subject).to receive(:new).with(expkey).and_call_original
      subject.choose(expkey)
    end

    it 'calls choose on the ExperimentProxy with the provided arguments' do
      expect(exproxy).to receive(:choose).with(foo: :bar)
      subject.choose(expkey, foo: :bar)
    end
  end

  describe '#run!' do
    before {
      allow(subject).to receive(:new).and_return(exproxy)
      allow(exproxy).to receive(:run!).and_return(control)
    }

    it 'initializes an ExperimentProxy for the provided key' do
      expect(subject).to receive(:new).with(expkey)
      subject.run!(expkey)
    end

    it 'calls run! on the ExperimentProxy with the provided arguments' do
      expect(exproxy).to receive(:run!).with(foo: :bar)
      subject.run!(expkey, foo: :bar)
    end
  end

  describe '#run' do
    before {
      allow(subject).to receive(:new).and_return(exproxy)
      allow(exproxy).to receive(:run).and_return(control)
    }

    it 'initializes an ExperimentProxy for the provided key' do
      expect(subject).to receive(:new).with(expkey)
      subject.run(expkey)
    end

    it 'calls run on the ExperimentProxy with the provided arguments' do
      expect(exproxy).to receive(:run).with(foo: :bar)
      subject.run(expkey, foo: :bar)
    end
  end

  describe '#render!' do
    before {
      allow(subject).to receive(:new).and_return(exproxy)
      allow(exproxy).to receive(:render!).and_return(control)
    }

    it 'initializes an ExperimentProxy for the provided key' do
      expect(subject).to receive(:new).with(expkey)
      subject.render!(expkey)
    end

    it 'calls render! on the ExperimentProxy with the provided arguments' do
      expect(exproxy).to receive(:render!).with(foo: :bar)
      subject.render!(expkey, foo: :bar)
    end
  end

  describe '#render' do
    before {
      allow(subject).to receive(:new).and_return(exproxy)
      allow(exproxy).to receive(:render).and_return(control)
    }

    it 'initializes an ExperimentProxy for the provided key' do
      expect(subject).to receive(:new).with(expkey)
      subject.render(expkey)
    end

    it 'calls render on the ExperimentProxy with the provided arguments' do
      expect(exproxy).to receive(:render).with(foo: :bar)
      subject.render(expkey, foo: :bar)
    end
  end

  describe '#convert!' do
    before {
      allow(subject).to receive(:new).and_return(exproxy)
      allow(exproxy).to receive(:convert!).and_return(control)
    }

    it 'initializes an ExperimentProxy for the provided key' do
      expect(subject).to receive(:new).with(expkey)
      subject.convert!(expkey)
    end

    it 'calls convert! on the ExperimentProxy with the provided arguments' do
      expect(exproxy).to receive(:convert!).with(:checkpoint, foo: :bar)
      subject.convert!(expkey, :checkpoint, foo: :bar)
    end
  end

  describe '#convert' do
    before {
      allow(subject).to receive(:new).and_return(exproxy)
      allow(exproxy).to receive(:convert).and_return(control)
    }

    it 'initializes an ExperimentProxy for the provided key' do
      expect(subject).to receive(:new).with(expkey)
      subject.convert(expkey)
    end

    it 'calls convert on the ExperimentProxy with the provided arguments' do
      expect(exproxy).to receive(:convert).with(:checkpoint, foo: :bar)
      subject.convert(expkey, :checkpoint, foo: :bar)
    end
  end

  describe '#participant' do
    it 'returns the participant' do
      expect(subject.participant).to be(participant)
    end

    context 'when no participant has been provided' do
      subject { described_class.new(context) }

      it 'calls trailguide_participant on the context' do
        expect(context).to receive(:trailguide_participant)
        subject.participant
      end
    end
  end

  describe '#context_type' do
    it 'returns nil' do
      expect(subject.context_type).to be_nil
    end

    context 'when context is a view' do
      let(:context) { ActionView::Context.new }
      let(:context) { Class.new { include ActionView::Context }.new }

      it 'returns template' do
        expect(subject.context_type).to eq(:template)
      end
    end

    context 'when context is a controller' do
      let(:context) { ActionController::Base.new }

      it 'returns controller' do
        expect(subject.context_type).to eq(:controller)
      end
    end
  end
end
