require 'rails_helper'

RSpec.describe TrailGuide::CombinedExperiment do

  describe '.configuration' do
    combined { |cfg| cfg.combined = [:first_combo, :second_combo] }
    subject { combined.first }

    it 'returns the configuration object for the experiment' do
      expect(subject.configuration).to be_an_instance_of(TrailGuide::Experiments::CombinedConfig)
    end

    it 'memoizes the configuration object' do
      expect(subject.instance_variable_get(:@configuration)).to eq(subject.configuration)
    end
  end

  describe '.parent' do
    combined { |cfg| cfg.combined = [:first_combo, :second_combo] }
    subject { combined.first }

    it 'delegates to the configuration object' do
      expect(subject.configuration).to receive(:parent)
      subject.parent
    end

    it 'returns the parent experiment' do
      expect(subject.parent).to eq(experiment)
    end
  end

  describe '.is_combined?' do
    combined { |cfg| cfg.combined = [:first_combo, :second_combo] }
    subject { combined.first }

    it 'returns true' do
      expect(subject.is_combined?).to be_truthy
    end
  end

  describe '.start!' do
    combined { |cfg| cfg.combined = [:first_combo, :second_combo] }
    subject { combined.first }

    it 'delegates to the parent' do
      expect(experiment).to receive(:start!)
      subject.start!
    end
  end

  describe '.stop!' do
    combined { |cfg| cfg.combined = [:first_combo, :second_combo] }
    subject { combined.first }

    it 'delegates to the parent' do
      expect(experiment).to receive(:stop!)
      subject.stop!
    end
  end

  describe '.pause!' do
    combined { |cfg| cfg.combined = [:first_combo, :second_combo] }
    subject { combined.first }

    it 'delegates to the parent' do
      expect(experiment).to receive(:pause!)
      subject.pause!
    end
  end

  describe '.resume!' do
    combined { |cfg| cfg.combined = [:first_combo, :second_combo] }
    subject { combined.first }

    it 'delegates to the parent' do
      expect(experiment).to receive(:resume!)
      subject.resume!
    end
  end

  describe '.started_at' do
    combined { |cfg| cfg.combined = [:first_combo, :second_combo] }
    subject { combined.first }

    it 'delegates to the parent' do
      expect(experiment).to receive(:started_at)
      subject.started_at
    end
  end

  describe '.paused_at' do
    combined { |cfg| cfg.combined = [:first_combo, :second_combo] }
    subject { combined.first }

    it 'delegates to the parent' do
      expect(experiment).to receive(:paused_at)
      subject.paused_at
    end
  end

  describe '.stopped_at' do
    combined { |cfg| cfg.combined = [:first_combo, :second_combo] }
    subject { combined.first }

    it 'delegates to the parent' do
      expect(experiment).to receive(:stopped_at)
      subject.stopped_at
    end
  end
end
