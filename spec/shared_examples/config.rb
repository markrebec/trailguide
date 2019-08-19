RSpec.shared_examples 'a boolean config method' do |meth|
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
    let(:config_hash) { {meth => true} }

    it 'returns true' do
      expect(subject.send("#{meth}?")).to eq(true)
    end
  end
end

RSpec.shared_examples 'a callback config method' do |meth|
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

  context 'with no arguments' do
    it 'raises an ArgumentError' do
      expect { subject.send(meth) }.to raise_exception(ArgumentError)
    end
  end

  context 'when configured via hash arguments' do
    let(:config_hash) { {meth => [:dummy]} }

    it 'adds the callback to the list' do
      expect(subject[meth]).to eq([:dummy])
    end
  end
end
