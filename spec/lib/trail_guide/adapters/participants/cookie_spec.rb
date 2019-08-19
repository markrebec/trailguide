require 'rails_helper'
require 'shared_examples/participant_adapter'

RSpec.describe TrailGuide::Adapters::Participants::Cookie do
  subject { described_class.new(context) }
  let(:context) do
    Class.new do
      def cookies
        {}
      end
    end.new
  end

  it_behaves_like 'a participant adapter'

  describe '#initialize' do
    it 'returns an Adapter class' do
      expect(subject).to be_an_instance_of(TrailGuide::Adapters::Participants::Cookie::Adapter)
    end

    it 'sets a default cookie name' do
      expect(subject.config.cookie).to eq(:trailguide)
    end

    it 'sets a default cookie path' do
      expect(subject.config.path).to eq('/')
    end

    it 'sets a default cookie expiration' do
      expect(subject.config.expiration).to eq(1.year.to_i)
    end

    context 'when configured with a cookie name' do
      subject { described_class.new(context) { |cfg| cfg.cookie = :foobar } }

      it 'uses the configured name' do
        expect(subject.config.cookie).to eq(:foobar)
      end
    end

    context 'when configured with a cookie path' do
      subject { described_class.new(context) { |cfg| cfg.path = '/foobar' } }

      it 'uses the configured path' do
        expect(subject.config.path).to eq('/foobar')
      end
    end

    context 'when configured with a cookie expiration' do
      subject { described_class.new(context) { |cfg| cfg.expiration = 1.month.to_i } }

      it 'uses the configured expiration' do
        expect(subject.config.expiration).to eq(1.month.to_i)
      end
    end

    context 'when the context does not support cookies' do
      it 'raises an UnsupportedContextError' do
        expect { described_class.new(nil) }.to raise_exception(TrailGuide::UnsupportedContextError)
      end
    end
  end
end
