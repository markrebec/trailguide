require 'rails_helper'

RSpec.describe TrailGuide::Variant do
  let(:experiment) { create_experiment :test_experiment }
  subject { TrailGuide::Variant.new(experiment, :test_variant_a) }

  describe '#==' do
    context 'when other is a variant object' do
      context 'which is a match' do
        let(:other) { TrailGuide::Variant.new(experiment, :test_variant_a) }

        it 'returns true' do
          expect(subject).to eq(other)
        end
      end

      context 'which is not a match' do
        let(:other) { TrailGuide::Variant.new(experiment, :test_variant_b) }

        it 'returns false' do
          expect(subject).to_not eq(other)
        end
      end
    end

    context 'when other is a string' do
      context 'which is a match' do
        let(:other) { 'test_variant_a' }

        it 'returns true' do
          expect(subject).to eq(other)
        end
      end

      context 'which is not a match' do
        let(:other) { 'test_variant_b' }

        it 'returns false' do
          expect(subject).to_not eq(other)
        end
      end
    end

    context 'when other is a symbol' do
      context 'which is a match' do
        let(:other) { :test_variant_a }

        it 'returns true' do
          expect(subject).to eq(other)
        end
      end

      context 'which is not a match' do
        let(:other) { :test_variant_b }

        it 'returns false' do
          expect(subject).to_not eq(other)
        end
      end
    end
  end

  describe '#control!' do
    it 'flags the variant as a control' do
      expect { subject.control! }.to change { subject.control? }.from(false).to(true)
    end
  end

  describe '#variant!' do
    subject { TrailGuide::Variant.new(experiment, :test_variant_a, control: true) }

    it 'flags the variant as not a control' do
      expect { subject.variant! }.to change { subject.control? }.from(true).to(false)
    end
  end

  describe '#control?' do
    context 'when the variant is a control' do
      subject { TrailGuide::Variant.new(experiment, :test_variant_a, control: true) }

      it 'returns true' do
        expect(subject.control?).to eq(true)
      end
    end

    context 'when the variant is not a control' do
      it 'returns false' do
        expect(subject.control?).to eq(false)
      end
    end
  end

  describe '#persisted?' do
    it 'checks if the redis key exists' do
      expect(TrailGuide.redis).to receive(:exists).with(subject.storage_key)
      subject.persisted?
    end
  end

  describe '#save!' do
    it 'saves the variant to redis' do
      expect(TrailGuide.redis).to receive(:hsetnx).with(subject.storage_key, 'name', subject.name)
      subject.save!
    end
  end

  describe '#delete!' do
    it 'deletes the variant from redis' do
      expect(TrailGuide.redis).to receive(:del).with(subject.storage_key)
      subject.delete!
    end
  end

  describe '#reset!' do
    it 'deletes and re-saves the variant' do
      expect(subject).to receive(:delete!)
      expect(subject).to receive(:save!)
      subject.reset!
    end
  end

  describe '#participants' do
    let(:participant_count) { 20 }

    before do
      participant_count.times { subject.increment_participation! }
    end

    it 'returns the number of counted participants' do
      expect(subject.participants).to eq(participant_count)
    end
  end

  describe '#converted' do
    context 'without any experiment goals' do
      let(:participant_count) { 20 }
      let(:converted_count) { 10 }

      before do
        participant_count.times { subject.increment_participation! }
        converted_count.times { subject.increment_conversion! }
      end

      it 'does not accept a checkpoint' do
        expect { subject.converted(:test_goal_one) }.to raise_error(TrailGuide::InvalidGoalError)
      end

      it 'returns the number of converted participants' do
        expect(subject.converted).to eq(converted_count)
      end
    end

    context 'with experiment goals defined' do
      let(:experiment) do
        create_experiment :test_experiment, goals: [:test_goal_one, :test_goal_two]
      end
      let(:participant_count) { 20 }
      let(:goal_one_count) { 5 }
      let(:goal_two_count) { 10 }

      before do
        participant_count.times { subject.increment_participation! }
        goal_one_count.times { subject.increment_conversion!(:test_goal_one) }
        goal_two_count.times { subject.increment_conversion!(:test_goal_two) }
      end

      context 'without a goal checkpoint' do
        it 'returns the total number of converted participants' do
          expect(subject.converted).to eq(15)
        end
      end

      context 'with a goal checkpoint' do
        it 'requires a valid goal checkpoint' do
          expect { subject.converted(:foobar_goal) }.to raise_error(TrailGuide::InvalidGoalError)
        end

        it 'returns the number of converted participants for the goal' do
          expect(subject.converted(:test_goal_one)).to eq(5)
          expect(subject.converted(:test_goal_two)).to eq(10)
        end
      end
    end
  end

  describe '#unconverted' do
    context 'without any experiment goals' do
      let(:participant_count) { 20 }
      let(:converted_count) { 10 }

      before do
        participant_count.times { subject.increment_participation! }
        converted_count.times { subject.increment_conversion! }
      end

      it 'returns the number of participants who have not converted' do
        expect(subject.unconverted).to eq(10)
      end
    end

    context 'with experiment goals defined' do
      let(:experiment) do
        create_experiment :test_experiment, goals: [:test_goal_one, :test_goal_two]
      end
      let(:participant_count) { 20 }
      let(:goal_one_count) { 5 }
      let(:goal_two_count) { 10 }

      before do
        participant_count.times { subject.increment_participation! }
        goal_one_count.times { subject.increment_conversion!(:test_goal_one) }
        goal_two_count.times { subject.increment_conversion!(:test_goal_two) }
      end

      it 'returns the total number of participants who have not converted' do
        expect(subject.unconverted).to eq(5)
      end
    end
  end

  describe '#increment_participation!' do
    it 'increments the redis participants key by 1' do
      expect(TrailGuide.redis).to receive(:hincrby).with(subject.storage_key, 'participants', 1)
      subject.increment_participation!
    end
  end

  describe '#increment_conversion!' do
    context 'without any experiment goals' do
      let(:participant_count) { 20 }
      let(:converted_count) { 10 }

      before do
        participant_count.times { subject.increment_participation! }
        converted_count.times { subject.increment_conversion! }
      end

      it 'increments the redis converted key by 1' do
        expect(TrailGuide.redis).to receive(:hincrby).with(subject.storage_key, 'converted', 1)
        subject.increment_conversion!
      end
    end

    context 'with experiment goals defined' do
      let(:experiment) do
        create_experiment :test_experiment, goals: [:test_goal_one, :test_goal_two]
      end
      let(:participant_count) { 20 }
      let(:goal_one_count) { 5 }
      let(:goal_two_count) { 10 }

      before do
        participant_count.times { subject.increment_participation! }
        goal_one_count.times { subject.increment_conversion!(:test_goal_one) }
        goal_two_count.times { subject.increment_conversion!(:test_goal_two) }
      end

      context 'with a goal checkpoint' do
        it 'increments the redis goal conversion key' do
          expect(TrailGuide.redis).to receive(:hincrby).with(subject.storage_key, 'test_goal_one', 1)
          subject.increment_conversion!(:test_goal_one)
        end
      end
    end
  end

  describe '#storage_key' do
    it 'joins the experiment and variant names together' do
      expect(subject.storage_key).to eq('test_experiment:test_variant_a')
    end
  end
end
