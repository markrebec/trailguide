require 'rails_helper'
require 'shared_examples/participant_adapter'

RSpec.describe TrailGuide::Adapters::Participants::Redis do
  subject { described_class.new(context) }
  let(:context) do
    Class.new { }.new
  end

  it_behaves_like 'a participant adapter'

  describe '#initialize' do
    it 'returns an Adapter class' do
      expect(subject).to be_an_instance_of(TrailGuide::Adapters::Participants::Redis::Adapter)
    end

    it 'sets a default key namespace' do
      expect(subject.config.namespace).to eq(:participants)
    end

    context 'when configured with a key namespace' do
      subject { described_class.new(context) { |cfg| cfg.namespace = :foobar } }

      it 'uses the configured key namespace' do
        expect(subject.config.namespace).to eq(:foobar)
      end
    end

    context 'when configured with a lookup proc' do
      let(:lookup) { -> (ctx) { return :foobar } }
      subject { described_class.new(context) { |cfg| cfg.lookup = lookup } }

      it 'uses the configured lookup proc' do
        expect(subject.config.lookup).to respond_to(:call)
      end

      it 'uses the return value to set the storage key' do
        expect(subject.instance_variable_get(:@storage_key)).to eq("#{subject.config.namespace}:foobar")
      end
    end

    context 'when configured with a lookup method' do
      subject { described_class.new(context) { |cfg| cfg.lookup = :lookup_method } }
      let(:context) do
        Class.new do
          def lookup_method
            :foobar
          end
        end.new
      end

      it 'uses the configured lookup method' do
        expect(subject.config.lookup).to eq(:lookup_method)
      end

      it 'uses the return value to set the storage key' do
        expect(subject.instance_variable_get(:@storage_key)).to eq("#{subject.config.namespace}:foobar")
      end
    end

    context 'when a key argument is provided' do
      subject { described_class::Adapter.new(context, described_class.new(context).configuration, key: :foobar) }

      it 'uses the key instead of the lookup proc' do
        expect(subject.instance_variable_get(:@storage_key)).to eq("#{subject.config.namespace}:foobar")
      end
    end

    context 'when no lookup proc is configured' do
      it 'raises an ArgumentError' do
        expect { described_class.new(nil) { |cfg| cfg.lookup = nil } }.to raise_exception(ArgumentError)
      end
    end
  end
end
