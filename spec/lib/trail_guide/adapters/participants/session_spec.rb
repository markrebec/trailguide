require 'rails_helper'
require 'shared_examples/adapters/participant'

RSpec.describe TrailGuide::Adapters::Participants::Session do
  subject { described_class.new(context) }
  let(:context) do
    Class.new do
      def session
        @session ||= {}
      end
    end.new
  end

  it_behaves_like 'a participant adapter'

  describe '#initialize' do
    it 'returns an Adapter class' do
      expect(subject).to be_an_instance_of(TrailGuide::Adapters::Participants::Session::Adapter)
    end

    it 'sets a default session key' do
      expect(subject.config.key).to eq(:trailguide)
    end

    context 'when configured with a session key' do
      subject { described_class.new(context) { |cfg| cfg.key = :foobar } }

      it 'uses the configured key' do
        expect(subject.config.key).to eq(:foobar)
      end
    end

    context 'when the context does not support sessions' do
      it 'raises an UnsupportedContextError' do
        expect { described_class.new(nil) }.to raise_exception(TrailGuide::UnsupportedContextError)
      end
    end
  end
end
