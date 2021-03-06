require 'rails_helper'
require 'shared_examples/adapters/variant'

RSpec.describe TrailGuide::Adapters::Variants::Redis do
  experiment
  variant(:control)
  subject { described_class.new(variant) }

  it_behaves_like 'a variant adapter'

  describe '#initialize' do
    context 'when a redis client is provided' do
      let(:redis) { Redis.new }
      subject { described_class.new(variant, redis: redis) }

      it 'memoizes the @redis client' do
        expect(subject.instance_variable_get(:@redis)).to be(redis)
      end
    end
  end

  describe '#redis' do
    it 'memoizes the @redis client' do
      expect { subject.redis }.to change { subject.instance_variable_get(:@redis) }.from(nil)
    end

    context 'when no client has been provided' do
      it 'falls back to the TrailGuide client' do
        expect(subject.redis).to be(TrailGuide.redis)
      end
    end

    context 'when a client has been provided' do
      let(:redis) { Redis.new }
      subject { described_class.new(variant, redis: redis) }

      it 'uses the provided client' do
        expect(subject.redis).to be(redis)
      end
    end
  end

  describe '#get' do
    it 'uses hget to get the hash key under the storage key' do
      expect(subject.redis).to receive(:hget).with(variant.storage_key, 'foobar')
      subject.get(:foobar)
    end
  end

  describe '#set' do
    it 'uses hset to set the hash key under the storage key' do
      expect(subject.redis).to receive(:hset).with(variant.storage_key, 'foobar', 'baz')
      subject.set(:foobar, :baz)
    end
  end

  describe '#setnx' do
    it 'uses hsetnx to set the hash key under the storage key' do
      expect(subject.redis).to receive(:hsetnx).with(variant.storage_key, 'foobar', 'baz')
      subject.setnx(:foobar, :baz)
    end
  end

  describe '#increment' do
    it 'uses hincrby to increment the hash key under the storage key' do
      expect(subject.redis).to receive(:hincrby).with(variant.storage_key, 'foobar', 1)
      subject.increment(:foobar)
    end
  end

  describe '#delete' do
    it 'uses hdel to delete the hash key under the storage key' do
      expect(subject.redis).to receive(:hdel).with(variant.storage_key, 'foobar')
      subject.delete(:foobar)
    end
  end

  describe '#exists?' do
    it 'uses hexists to check if the hask hey exists under the storage key' do
      expect(subject.redis).to receive(:hexists).with(variant.storage_key, 'foobar')
      subject.exists?(:foobar)
    end
  end

  describe '#persisted?' do
    it 'uses exists? to check of the storage key exists' do
      expect(subject.redis).to receive(:exists?).with(variant.storage_key)
      subject.persisted?
    end
  end

  describe '#destroy' do
    it 'uses del to delete the storage key' do
      expect(subject.redis).to receive(:del).with(variant.storage_key)
      subject.destroy
    end
  end
end
