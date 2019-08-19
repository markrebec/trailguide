require 'rails_helper'

RSpec.describe TrailGuide::Adapters::Participants::Base do
  context 'when inheriting a custom adapter' do
    subject {
      Object.send(:remove_const, :CustomAdapter) if defined?(CustomAdapter)
      CustomAdapter = Class.new(described_class)
      CustomAdapter.new(nil)
    }

    describe '#[]' do
      it 'raises a NotImplementedError' do
        expect { subject['foo'] }.to raise_exception(NotImplementedError)
      end
    end

    describe '#[]=' do
      it 'raises a NotImplementedError' do
        expect { subject['foo'] = 'bar' }.to raise_exception(NotImplementedError)
      end
    end

    describe '#delete' do
      it 'raises a NotImplementedError' do
        expect { subject.delete('foo') }.to raise_exception(NotImplementedError)
      end
    end

    describe '#destroy!' do
      it 'raises a NotImplementedError' do
        expect { subject.destroy! }.to raise_exception(NotImplementedError)
      end
    end

    describe '#keys' do
      it 'raises a NotImplementedError' do
        expect { subject.keys }.to raise_exception(NotImplementedError)
      end
    end

    describe '#key?' do
      it 'raises a NotImplementedError' do
        expect { subject.key?('foo') }.to raise_exception(NotImplementedError)
      end
    end

    describe '#to_h' do
      it 'raises a NotImplementedError' do
        expect { subject.to_h }.to raise_exception(NotImplementedError)
      end
    end
  end
end
