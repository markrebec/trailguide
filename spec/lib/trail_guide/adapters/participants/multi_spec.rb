require 'rails_helper'
require 'shared_examples/adapters/participant'

RSpec.describe TrailGuide::Adapters::Participants::Multi do
  subject { described_class.new(context) }
  let(:context) { Class.new { }.new }

  describe '#initialize' do
    context 'with a custom adapter proc' do
      let(:context) {
        Class.new {
          def trailguide_user
            Struct.new(:id).new(1)
          end
        }.new
      }
      let(:adapter) { -> (ctx) { return TrailGuide::Adapters::Participants::Anonymous } }
      subject { described_class.new(context) { |cfg| cfg.adapter = adapter } }

      it 'calls the configured proc' do
        expect(adapter).to receive(:call).and_return(TrailGuide::Adapters::Participants::Anonymous)
        described_class.new(context) { |cfg| cfg.adapter = adapter }
      end

      it 'uses the returned adapter' do
        expect(subject).to be_an_instance_of(TrailGuide::Adapters::Participants::Anonymous::Adapter)
      end
    end

    context 'with the default adapter proc' do
      context 'when the context responds with a trailguide_user' do
        let(:context) {
          Class.new {
            def trailguide_user
              Struct.new(:id).new(1)
            end
          }.new
        }

        it 'uses the redis adapter' do
          expect(subject).to be_an_instance_of(TrailGuide::Adapters::Participants::Redis::Adapter)
        end
      end

      context 'when the context responds with a current_user' do
        let(:context) {
          Class.new {
            def current_user
              Struct.new(:id).new(1)
            end
          }.new
        }

        it 'uses the redis adapter' do
          expect(subject).to be_an_instance_of(TrailGuide::Adapters::Participants::Redis::Adapter)
        end
      end

      context 'when the context supports cookies' do
        let(:context) {
          Class.new {
            def cookies
              @cookies ||= {}
            end
          }.new
        }

        it 'uses the cookie adapter' do
          expect(subject).to be_an_instance_of(TrailGuide::Adapters::Participants::Cookie::Adapter)
        end
      end

      context 'when the context supports sessions' do
        let(:context) {
          Class.new {
            def session
              @session ||= {}
            end
          }.new
        }

        it 'uses the session adapter' do
          expect(subject).to be_an_instance_of(TrailGuide::Adapters::Participants::Session::Adapter)
        end
      end

      context 'when the context does not support cookies, sessions or identifying a user' do
        it 'uses the anonymous adapter' do
          expect(subject).to be_an_instance_of(TrailGuide::Adapters::Participants::Anonymous::Adapter)
        end
      end
    end
  end
end
