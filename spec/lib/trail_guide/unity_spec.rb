require 'rails_helper'
require 'trail_guide/unity'

RSpec.describe TrailGuide::Unity do
  describe "clear!" do
    let(:keys) { 5.times.map { |i| "#{TrailGuide::Unity::NAMESPACE}:test_key:#{i}" } }

    before { keys.each { |key| TrailGuide.redis.set(key, "foobar") } }

    it "clears all keys under the namespace" do
      expect(TrailGuide.redis).to receive(:del) { |*args| expect(args.sort).to eq(TrailGuide.redis.keys("#{TrailGuide::Unity::NAMESPACE}:*").sort) }
      TrailGuide::Unity.clear!
    end
  end

  describe "#user_id=" do
    subject { described_class.new }

    it "sets the user_id" do
      subject.user_id = 123
      expect(subject.user_id).to eq("123")
    end
  end

  describe "#visitor_id=" do
    subject { described_class.new }

    it "sets the visitor_id" do
      subject.user_id = 123
      expect(subject.user_id).to eq("123")
    end
  end

  describe "#stored_user_id" do
    subject { described_class.new(visitor_id: 123) }

    context "when a visitor_id is present" do
      context "and a user_id is linked" do
        before { described_class.new(visitor_id: 123, user_id: 456).save! }

        it "returns the linked user_id" do
          expect(subject.stored_user_id).to eq("456")
        end
      end

      context "and a user_id is not linked" do
        it "returns nil" do
          expect(subject.stored_user_id).to be_nil
        end
      end
    end

    context "when no visitor_id is present" do
      it "returns nil" do
        expect(subject.stored_user_id).to be_nil
      end
    end
  end

  describe "#stored_visitor_id" do
    subject { described_class.new(user_id: 456) }

    context "when a user_id is present" do
      context "and a visitor_id is linked" do
        before { described_class.new(visitor_id: 123, user_id: 456).save! }

        it "returns the linked visitor_id" do
          expect(subject.stored_visitor_id).to eq("123")
        end
      end

      context "and a visitor_id is not linked" do
        it "returns nil" do
          expect(subject.stored_visitor_id).to be_nil
        end
      end
    end

    context "when no user_id is present" do
      it "returns nil" do
        expect(subject.stored_visitor_id).to be_nil
      end
    end
  end

  describe "#valid?" do
    context "when both IDs are present" do
      subject { described_class.new(visitor_id: 123, user_id: 456) }

      it "returns true" do
        expect(subject.valid?).to be_truthy
      end
    end

    context "when neither ID is present" do
      subject { described_class.new }

      it "returns false" do
        expect(subject.valid?).to be_falsey
      end
    end

    context "when no user_id is present" do
      subject { described_class.new(visitor_id: 123) }

      it "returns false" do
        expect(subject.valid?).to be_falsey
      end
    end

    context "when no visitor_id is present" do
      subject { described_class.new(user_id: 456) }

      it "returns false" do
        expect(subject.valid?).to be_falsey
      end
    end
  end

  describe "#stored?" do
    context "when both stored IDs are present" do
      subject { described_class.new(visitor_id: 123, user_id: 456) }
      before  { described_class.new(visitor_id: 123, user_id: 456).save! }

      it "returns true" do
        expect(subject.stored?).to be_truthy
      end
    end

    context "when neither stored ID is present" do
      subject { described_class.new(visitor_id: 123, user_id: 456) }

      it "returns false" do
        expect(subject.stored?).to be_falsey
      end
    end

    context "when no stored user_id is present" do
      subject { described_class.new(visitor_id: 123, user_id: 456) }
      before  { described_class.new(visitor_id: 321, user_id: 456).save! }

      it "returns false" do
        expect(subject.stored?).to be_falsey
      end
    end

    context "when no stored visitor_id is present" do
      subject { described_class.new(visitor_id: 123, user_id: 456) }
      before  { described_class.new(visitor_id: 123, user_id: 654).save! }

      it "returns false" do
        expect(subject.stored?).to be_falsey
      end
    end
  end

  describe "#synced?" do
    context "when the IDs are not valid" do
      subject { described_class.new }

      it "returns false" do
        expect(subject.synced?).to be_falsey
      end
    end

    context "when the stored IDs are not present" do
      subject { described_class.new(visitor_id: 123, user_id: 456) }

      it "returns false" do
        expect(subject.synced?).to be_falsey
      end
    end

    context "when the visitor_ids do not match" do
      subject { described_class.new(visitor_id: 123, user_id: 456) }
      before  { described_class.new(visitor_id: 321, user_id: 456).save! }

      it "returns false" do
        expect(subject.synced?).to be_falsey
      end
    end

    context "when the user_ids do not match" do
      subject { described_class.new(visitor_id: 123, user_id: 456) }
      before  { described_class.new(visitor_id: 123, user_id: 654).save! }

      it "returns false" do
        expect(subject.synced?).to be_falsey
      end
    end

    context "when the IDs match the stored IDs" do
      subject { described_class.new(visitor_id: 123, user_id: 456) }
      before  { described_class.new(visitor_id: 123, user_id: 456).save! }

      it "returns true" do
        expect(subject.synced?).to be_truthy
      end
    end
  end

  describe "#sync!" do
    subject { described_class.new(visitor_id: 123, user_id: 456) }

    it "deletes any existing keys" do
      expect(subject).to receive(:delete!)
      subject.sync!
    end

    it "saves the new keys" do
      expect(subject).to receive(:save!)
      subject.sync!
    end

    context "when no user_id is present" do
      subject { described_class.new(visitor_id: 123) }

      context "and a stored user_id is present" do
        before  { described_class.new(visitor_id: 123, user_id: 456).save! }

        it "sets the user_id to the stored user_id" do
          expect { subject.sync! }.to change { subject.user_id }.to("456")
        end
      end
    end

    context "when no visitor_id is present" do
      subject { described_class.new(user_id: 456) }

      context "and a stored visitor_id is present" do
        before  { described_class.new(visitor_id: 123, user_id: 456).save! }

        it "sets the visitor_id to the stored visitor_id" do
          expect { subject.sync! }.to change { subject.visitor_id }.to("123")
        end
      end
    end
  end

  describe "#save!" do
    context "when the IDs are not valid" do
      subject { described_class.new }

      it "returns false" do
        expect(subject.save!).to be_falsey
      end

      it "does not set redis keys" do
        expect(TrailGuide.redis).to_not receive(:set)
        subject.save!
      end
    end

    context "when the IDs are valid" do
      subject { described_class.new(visitor_id: 123, user_id: 456) }

      it "returns true" do
        expect(subject.save!).to be_truthy
      end

      it "sets the redis ID keys" do
        expect(TrailGuide.redis).to receive(:set).with(subject.send(:user_key), "123")
        expect(TrailGuide.redis).to receive(:set).with(subject.send(:visitor_key), "456")
        subject.save!
      end

      context "when a ttl has been configured" do
        before { TrailGuide.configuration.unity_ttl = 30 }
        after  { TrailGuide.configuration.unity_ttl = nil }

        it "sets the expiration on the keys" do
          expect(TrailGuide.redis).to receive(:expire).with(subject.send(:user_key), 30)
          expect(TrailGuide.redis).to receive(:expire).with(subject.send(:visitor_key), 30)
          subject.save!
        end
      end
    end
  end

  describe "#delete!" do
    subject { described_class.new(visitor_id: 123, user_id: 456) }
    before  { subject.save! }

    it "deletes all matching ID keys" do
      expect(TrailGuide.redis).to receive(:del).with(
        subject.send(:stored_user_key),
        subject.send(:stored_visitor_key),
        subject.send(:user_key),
        subject.send(:visitor_key)
      )
      subject.delete!
    end
  end
end
