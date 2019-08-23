require 'rails_helper'

RSpec.describe TrailGuide::Helper do
  experiment
  participant
  variant(:control)
  subject { Class.new { include TrailGuide::Helper }.new }
  let(:expkey) { experiment.experiment_name }
  before { allow_any_instance_of(experiment).to receive(:choose!).and_return(control) }

  describe '#trailguide' do
    context 'without a key' do
      it 'returns a helper proxy' do
        expect(subject.trailguide).to be_a(TrailGuide::Helper::HelperProxy)
      end
    end

    context 'with a key' do
      it 'automatically calls choose against the proxy' do
        expect_any_instance_of(TrailGuide::Helper::HelperProxy).to receive(:choose!)
        subject.trailguide(expkey)
      end

      it 'returns the chosen variant' do
        expect(subject.trailguide(expkey)).to be(control)
      end
    end

    context 'when the context changes between uses of the memoized proxy' do
      let(:other) { Class.new { include TrailGuide::Helper }.new }
      let(:proxy) { TrailGuide::Helper::HelperProxy.new(other, participant: participant) }
      before { subject.instance_variable_set(:@trailguide_proxy, proxy) }

      it 'initializes a new proxy with the new context' do
        expect { subject.trailguide }.to change { subject.instance_variable_get(:@trailguide_proxy) }
      end
    end
  end

  describe '#trailguide_participant' do
    it 'returns a trailguide participant' do
      expect(subject.trailguide_participant).to be_a(TrailGuide::Participant)
    end

    context 'when the context changes between uses of the memoized participant' do
      let(:other) { Class.new { include TrailGuide::Helper }.new }
      let(:proxy) { TrailGuide::Helper::HelperProxy.new(other, participant: participant) }
      before { subject.instance_variable_set(:@trailguide_participant, other.trailguide_participant) }

      it 'initializes a new participant with the new context' do
        expect { subject.trailguide_participant }.to change { subject.instance_variable_get(:@trailguide_participant) }
      end
    end
  end

  describe '#trailguide_excluded_request?' do
    it 'executes the configured block within the context' do
      expect(subject).to receive(:instance_exec).with(subject) { |&blk| expect(blk).to be(TrailGuide.configuration.request_filter) }
      subject.trailguide_excluded_request?
    end
  end

  describe '#is_preview?' do
    context 'when the context does not respond to request' do
      it 'returns false' do
        expect(subject.is_preview?).to be_falsey
      end
    end

    context 'when the context responds to request' do
      context 'but the request does not have any headers' do
        subject { Class.new {
          include TrailGuide::Helper

          def request
            Struct.new(:headers).new(nil)
          end
        }.new }

        it 'returns false' do
          expect(subject.is_preview?).to be_falsey
        end
      end

      context 'and the preview header is set' do
        subject { Class.new {
          include TrailGuide::Helper

          def request
            Struct.new(:headers).new({'x-purpose' => 'preview'})
          end
        }.new }

        it 'returns true' do
          expect(subject.is_preview?).to be_truthy
        end
      end
    end
  end

  describe '#is_filtered_user_agent?' do
    subject { Class.new {
      include TrailGuide::Helper

      def request
        Struct.new(:user_agent).new('foobar')
      end
    }.new }

    it 'memoizes the proc' do
      expect { subject.is_filtered_user_agent? }.to change { subject.instance_variable_get(:@user_agent_filter_proc) }.from(nil)
    end

    it 'memoizes the result' do
      expect { subject.is_filtered_user_agent? }.to change { subject.instance_variable_get(:@is_filtered_user_agent) }.from(nil)
    end

    context 'when not configured with any user agents' do
      it 'returns false' do
        expect(subject.is_filtered_user_agent?).to be_falsey
      end
    end

    context 'when the context does not respond to request' do
      subject { Class.new { include TrailGuide::Helper }.new }

      it 'returns false' do
        expect(subject.is_filtered_user_agent?).to be_falsey
      end
    end

    context 'when the request user agent is not present' do
      subject { Class.new {
        include TrailGuide::Helper

        def request
          Struct.new(:user_agent).new(nil)
        end
      }.new }

      it 'returns false' do
        expect(subject.is_filtered_user_agent?).to be_falsey
      end
    end

    context 'when there are no matches in the list' do
      subject { Class.new {
        include TrailGuide::Helper

        def request
          Struct.new(:user_agent).new('foobar')
        end
      }.new }
      before { allow(TrailGuide.configuration).to receive(:filtered_user_agents).and_return(['baz', 'qux']) }

      it 'returns false' do
        expect(subject.is_filtered_user_agent?).to be_falsey
      end
    end

    context 'with a user agent string that matches' do
      subject { Class.new {
        include TrailGuide::Helper

        def request
          Struct.new(:user_agent).new('foobar')
        end
      }.new }
      before { allow(TrailGuide.configuration).to receive(:filtered_user_agents).and_return(['baz', 'qux', 'foobar']) }

      it 'returns true' do
        expect(subject.is_filtered_user_agent?).to be_truthy
      end
    end

    context 'with a regex pattern that matches' do
      subject { Class.new {
        include TrailGuide::Helper

        def request
          Struct.new(:user_agent).new('foobar')
        end
      }.new }
      before { allow(TrailGuide.configuration).to receive(:filtered_user_agents).and_return(['baz', 'qux', /foo.*/]) }

      it 'returns true' do
        expect(subject.is_filtered_user_agent?).to be_truthy
      end
    end
  end

  describe '#is_filtered_ip_address?' do
    subject { Class.new {
      include TrailGuide::Helper

      def request
        Struct.new(:ip).new('2.2.2.2')
      end
    }.new }

    it 'memoizes the proc' do
      expect { subject.is_filtered_ip_address? }.to change { subject.instance_variable_get(:@ip_address_filter_proc) }.from(nil)
    end

    it 'memoizes the result' do
      expect { subject.is_filtered_ip_address? }.to change { subject.instance_variable_get(:@is_filtered_ip_address) }.from(nil)
    end

    context 'when not configured with any ip addresses' do
      it 'returns false' do
        expect(subject.is_filtered_ip_address?).to be_falsey
      end
    end

    context 'when the context does not respond to request' do
      subject { Class.new { include TrailGuide::Helper }.new }

      it 'returns false' do
        expect(subject.is_filtered_ip_address?).to be_falsey
      end
    end

    context 'when the request ip address is not present' do
      subject { Class.new {
        include TrailGuide::Helper

        def request
          Struct.new(:ip).new(nil)
        end
      }.new }

      it 'returns false' do
        expect(subject.is_filtered_ip_address?).to be_falsey
      end
    end

    context 'when there are no matches in the list' do
      subject { Class.new {
        include TrailGuide::Helper

        def request
          Struct.new(:ip).new('2.2.2.2')
        end
      }.new }
      before { allow(TrailGuide.configuration).to receive(:filtered_ip_addresses).and_return(['1.1.1.1', '3.3.3.3']) }

      it 'returns false' do
        expect(subject.is_filtered_ip_address?).to be_falsey
      end
    end

    context 'with an ip address string that matches' do
      subject { Class.new {
        include TrailGuide::Helper

        def request
          Struct.new(:ip).new('2.2.2.2')
        end
      }.new }
      before { allow(TrailGuide.configuration).to receive(:filtered_ip_addresses).and_return(['1.1.1.1', '3.3.3.3', '2.2.2.2']) }

      it 'returns true' do
        expect(subject.is_filtered_ip_address?).to be_truthy
      end
    end

    context 'with a regex pattern that matches' do
      subject { Class.new {
        include TrailGuide::Helper

        def request
          Struct.new(:ip).new('2.2.2.2')
        end
      }.new }
      before { allow(TrailGuide.configuration).to receive(:filtered_ip_addresses).and_return(['1.1.1.1', '3.3.3.3', /2\.2\.2\.2/ ]) }

      it 'returns true' do
        expect(subject.is_filtered_ip_address?).to be_truthy
      end
    end

    context 'with a range of ip addresses that matches' do
      subject { Class.new {
        include TrailGuide::Helper

        def request
          Struct.new(:ip).new('2.2.2.2')
        end
      }.new }
      before { allow(TrailGuide.configuration).to receive(:filtered_ip_addresses).and_return(['1.1.1.1', '3.3.3.3', (IPAddr.new('2.2.2.1')..IPAddr.new('2.2.2.3'))]) }

      it 'returns true' do
        expect(subject.is_filtered_ip_address?).to be_truthy
      end
    end
  end
end
