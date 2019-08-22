RSpec.shared_examples 'a participant adapter' do
  describe '#[]' do
    context 'when the provided key exists' do
      before { subject['foo'] = 'bar' }

      it 'returns the stored value' do
        expect(subject['foo']).to eq('bar')
      end
    end

    context 'when the provided key does not exist' do
      it 'returns nil' do
        expect(subject['foo']).to be_nil
      end
    end
  end

  describe '#[]=' do
    it 'sets the provided key to the provided value' do
      expect { subject['foo'] = 'bar' }.to change { subject['foo'] }.from(nil).to('bar')
    end
  end

  describe '#delete' do
    before { subject['foo'] = 'bar' }

    it 'deletes the stored key' do
      expect { subject.delete('foo') }.to change { subject['foo'] }.from('bar').to(nil)
    end
  end

  describe '#destroy!' do
    before { subject['foo'] = 'bar' }

    it 'destroys all stored keys' do
      expect { subject.destroy! }.to change { subject.keys }.from(['foo']).to([])
    end
  end

  describe '#keys' do
    context 'when there are no stored keys' do
      it 'returns an empty array' do
        expect(subject.keys).to eq([])
      end
    end

    context 'when there are stored keys' do
      before {
        subject['foo'] = 'foo'
        subject['bar'] = 'bar'
        subject['baz'] = 'baz'
      }

      it 'returns a list of keys' do
        expect(subject.keys).to eq(['foo', 'bar', 'baz'])
      end
    end
  end

  describe '#key?' do
    context 'when the stored key does not exist' do
      it 'returns false' do
        expect(subject.key?('foo')).to be_falsey
      end
    end

    context 'when the stored key exists' do
      before { subject['foo'] = 'bar' }

      it 'returns true' do
        expect(subject.key?('foo')).to be_truthy
      end
    end
  end

  describe '#to_h' do
    before {
      subject['foo'] = 'foo'
      subject['bar'] = 'bar'
      subject['baz'] = 'baz'
    }

    it 'returns a hash of keys/values' do
      expect(subject.to_h).to eq({
        'foo' => 'foo',
        'bar' => 'bar',
        'baz' => 'baz'
      })
    end
  end
end
