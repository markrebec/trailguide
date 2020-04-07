require 'rails_helper'

RSpec.describe TrailGuide::Config do
  describe '#paths' do
    it 'returns a struct' do
      expect(subject.paths).to be_a(Struct)
    end

    describe '#configs' do
      it 'returns an array' do
        expect(subject.paths.configs).to be_a(Array)
      end
    end

    describe '#classes' do
      it 'returns an array' do
        expect(subject.paths.classes).to be_a(Array)
      end
    end
  end

  describe '#redis' do
    context 'when configured with a redis client' do
      let(:redis) { Redis.new }
      before { subject.redis = redis }

      it 'returns the redis client' do
        expect(subject.redis).to equal(redis)
      end
    end

    context 'when configured with a redis namespace client' do
      let(:redis) { Redis::Namespace.new(:test, redis: Redis.new) }
      before { subject.redis = redis }

      it 'returns the redis namespace client' do
        expect(subject.redis).to equal(redis)
      end
    end

    context 'when configured with a url' do
      before { subject.redis = 'redis://localhost:6379' }

      it 'returns a redis client configured with the url' do
        expect(subject.redis_client.host).to eq('localhost')
        expect(subject.redis_client.port).to eq(6379)
      end
    end

    context 'when not configured' do
      it 'returns a default redis client' do
        expect(subject.redis_client.host).to eq('127.0.0.1')
        expect(subject.redis_client.port).to eq(6379)
      end
    end
  end

  describe '#ignore_orpaned_groups?' do
    context 'when not configured' do
      it 'returns false' do
        expect(subject.ignore_orphaned_groups?).to eq(false)
      end
    end

    context 'when configured as true' do
      before { subject.ignore_orphaned_groups = true }

      it 'returns true' do
        expect(subject.ignore_orphaned_groups?).to eq(true)
      end
    end

    context 'when configured as false' do
      before { subject.ignore_orphaned_groups = false }

      it 'returns false' do
        expect(subject.ignore_orphaned_groups?).to eq(false)
      end
    end
  end

  describe '#filtered_user_agents' do
    context 'when not configured' do
      it 'returns an empty array' do
        expect(subject.filtered_user_agents).to eq([])
      end
    end

    context 'when configured with an array' do
      before { subject.filtered_user_agents = ['a', 'b', 'c'] }

      it 'returns the array' do
        expect(subject.filtered_user_agents).to eq(['a', 'b', 'c'])
      end
    end

    context 'when configured with a block' do
      before { subject.filtered_user_agents = -> { ['a', 'b', 'c'] } }

      it 'returns the result of the block' do
        expect(subject.filtered_user_agents).to eq(['a', 'b', 'c'])
      end
    end
  end

  describe '#filtered_ip_addresses' do
    context 'when not configured' do
      it 'returns an empty array' do
        expect(subject.filtered_ip_addresses).to eq([])
      end
    end

    context 'when configured with an array' do
      before { subject.filtered_ip_addresses = ['1.1.1.1', '2.2.2.2'] }

      it 'returns the array' do
        expect(subject.filtered_ip_addresses).to eq(['1.1.1.1', '2.2.2.2'])
      end
    end

    context 'when configured with a block' do
      before { subject.filtered_ip_addresses = -> { ['1.1.1.1', '2.2.2.2'] } }

      it 'returns the result of the block' do
        expect(subject.filtered_ip_addresses).to eq(['1.1.1.1', '2.2.2.2'])
      end
    end
  end
end
