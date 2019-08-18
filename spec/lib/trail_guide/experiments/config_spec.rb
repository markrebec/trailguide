require 'rails_helper'

RSpec.shared_examples 'a boolean method' do |meth|
  context 'when not configured' do
    before { subject.send("#{meth}=", nil) }

    it 'returns false' do
      expect(subject.send("#{meth}?")).to eq(false)
    end
  end

  context 'when configured as false' do
    before { subject.send("#{meth}=", false) }

    it 'returns false' do
      expect(subject.send("#{meth}?")).to eq(false)
    end
  end

  context 'when configured as true' do
    before { subject.send("#{meth}=", true) }

    it 'returns true' do
      expect(subject.send("#{meth}?")).to eq(true)
    end
  end

  context 'when configured via hash arguments' do
    subject { described_class.new(create_experiment(:config), **{meth => true}) }

    it 'returns true' do
      expect(subject.send("#{meth}?")).to eq(true)
    end
  end
end

RSpec.shared_examples 'a callback method' do |meth|
  context 'with a method' do
    it 'adds the method to the list of callbacks' do
      expect { subject.send(meth, :dummy) }.to change { subject[meth] }.to([:dummy])
    end

    context 'and a block' do
      let(:block) { -> { return nil } }

      it 'prefers the method' do
        expect { subject.send(meth, :dummy, &block) }.to change { subject[meth] }.to([:dummy])
      end
    end
  end

  context 'with a block' do
    let(:block) { -> { return nil } }

    it 'adds the block to the list of callbacks' do
      expect { subject.send(meth, &block) }.to change { subject[meth] }.to([block])
    end
  end

  context 'when configured via hash arguments' do
    subject { described_class.new(create_experiment(:config), **{meth => [:dummy]}) }

    it 'adds the callback to the list' do
      expect(subject[meth]).to eq([:dummy])
    end
  end
end

RSpec.describe TrailGuide::Experiments::Config do
  subject { described_class.new(create_experiment(:config)) }

  describe '#initialize' do
    pending
  end

  describe '#start_manually?' do
    it_behaves_like 'a boolean method', :start_manually
  end

  describe '#reset_manually?' do
    it_behaves_like 'a boolean method', :reset_manually
  end

  describe '#sticky_assignment?' do
    it_behaves_like 'a boolean method', :sticky_assignment
  end

  describe '#allow_multiple_conversions?' do
    it_behaves_like 'a boolean method', :allow_multiple_conversions
  end

  describe '#allow_multiple_goals?' do
    it_behaves_like 'a boolean method', :allow_multiple_goals
  end

  describe '#track_winner_conversions?' do
    it_behaves_like 'a boolean method', :track_winner_conversions
  end

  describe '#skip_request_filter?' do
    it_behaves_like 'a boolean method', :skip_request_filter
  end

  describe '#can_resume?' do
    it_behaves_like 'a boolean method', :can_resume
  end

  describe '#enable_calibration?' do
    it_behaves_like 'a boolean method', :enable_calibration
  end

  describe '#preview_url?' do
    it_behaves_like 'a boolean method', :preview_url

    context 'when configured with a value' do
      before { subject.preview_url = 'www.example.com/foobar' }

      it 'returns true' do
        expect(subject.preview_url?).to eq(true)
      end
    end
  end

  describe '#name' do
    pending
  end

  describe '#groups' do
    pending
  end

  describe '#groups=' do
    pending
  end

  describe '#group' do
    pending
  end

  describe '#group=' do
    pending
  end

  describe '#algorithm' do
    pending
  end

  describe '#variants' do
    pending
  end

  describe '#variant' do
    pending
  end

  describe '#control' do
    pending
  end

  describe '#control=' do
    pending
  end

  describe '#goal' do
    pending
  end

  describe '#goal=' do
    pending
  end

  describe '#goals' do
    pending
  end

  describe '#goals=' do
    pending
  end

  describe '#metric' do
    pending
  end

  describe '#metric=' do
    pending
  end

  describe '#metrics' do
    pending
  end

  describe '#metrics=' do
    pending
  end

  describe '#combined' do
    pending
  end

  describe '#combined?' do
    pending
  end

  describe '#callbacks' do
    pending
  end

  describe '#on_choose' do
    it_behaves_like 'a callback method', :on_choose
  end

  describe '#on_use' do
    it_behaves_like 'a callback method', :on_use
  end

  describe '#on_convert' do
    it_behaves_like 'a callback method', :on_convert
  end

  describe '#on_start' do
    it_behaves_like 'a callback method', :on_start
  end

  describe '#on_schedule' do
    it_behaves_like 'a callback method', :on_schedule
  end

  describe '#on_stop' do
    it_behaves_like 'a callback method', :on_stop
  end

  describe '#on_pause' do
    it_behaves_like 'a callback method', :on_pause
  end

  describe '#on_resume' do
    it_behaves_like 'a callback method', :on_resume
  end

  describe '#on_winner' do
    it_behaves_like 'a callback method', :on_winner
  end

  describe '#on_reset' do
    it_behaves_like 'a callback method', :on_reset
  end

  describe '#on_delete' do
    it_behaves_like 'a callback method', :on_delete
  end

  describe '#on_redis_failover' do
    it_behaves_like 'a callback method', :on_redis_failover
  end

  describe '#allow_participation' do
    it_behaves_like 'a callback method', :allow_participation
  end

  describe '#allow_conversion' do
    it_behaves_like 'a callback method', :allow_conversion
  end

  describe '#rollout_winner' do
    it_behaves_like 'a callback method', :rollout_winner
  end
end
