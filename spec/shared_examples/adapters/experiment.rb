RSpec.shared_examples 'an experiment adapter' do
  describe '#initialize' do
    it 'memoizes the @experiment' do
      expect(subject.instance_variable_get(:@experiment)).to be(experiment)
    end
  end

  describe '#get' do
    context 'when the attribute exists' do
      before { subject.set(:foobar, :baz) }

      it 'returns the stored value' do
        expect(subject.get(:foobar)).to eq('baz')
      end
    end

    context 'when the attribute does not exist' do
      it 'returns nil' do
        expect(subject.get(:foobar)).to be_nil
      end
    end
  end

  describe '#set' do
    it 'sets the attribute to the value' do
      expect { subject.set(:foobar, :baz) }.to change { subject.get(:foobar) }.from(nil).to('baz')
    end

    it 'returns the set value' do
      expect(subject.set(:foobar, :baz)).to eq('baz')
    end
  end

  describe '#setnx' do
    context 'when the attribute does not exist' do
      it 'sets the attribute to the value' do
        expect { subject.setnx(:foobar, :baz) }.to change { subject.get(:foobar) }.from(nil).to('baz')
      end

      it 'returns the set value' do
        expect(subject.setnx(:foobar, :baz)).to eq('baz')
      end
    end

    context 'when the attribute exists' do
      before { subject.set(:foobar, :baz) }

      it 'does not change the stored value' do
        expect { subject.setnx(:foobar, :qux) }.to_not change { subject.get(:foobar) }
      end

      it 'returns nil' do
        expect(subject.setnx(:foobar, :qux)).to be_nil
      end
    end
  end

  describe '#delete' do
    context 'when the attribute exists' do
      before { subject.set(:foobar, :baz) }

      it 'deletes the attribute' do
        expect { subject.delete(:foobar) }.to change { subject.get(:foobar) }.from('baz').to(nil)
      end
    end
  end

  describe '#exists?' do
    context 'when the attribute exists' do
      before { subject.set(:foobar, :baz) }

      it 'returns true' do
        expect(subject.exists?(:foobar)).to be_truthy
      end
    end

    context 'when the attribute does not exist' do
      it 'returns false' do
        expect(subject.exists?(:foobar)).to be_falsey
      end
    end
  end

  describe '#persisted?' do
    context 'when the experiment has been persisted' do
      before { subject.set(:foobar, :baz) }

      it 'returns true' do
        expect(subject.persisted?).to be_truthy
      end
    end

    context 'when the experiment has not been persisted' do
      it 'returns false' do
        expect(subject.persisted?).to be_falsey
      end
    end
  end

  describe '#destroy' do
    context 'when the experiment has been persisted' do
      before { subject.set(:foobar, :baz) }

      it 'deletes all experiment keys and data' do
        expect { subject.destroy }.to change { subject.persisted? }.from(true).to(false)
      end
    end
  end
end
