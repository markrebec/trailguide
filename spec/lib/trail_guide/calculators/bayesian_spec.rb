require 'rails_helper'
require 'integration'
require 'rubystats'
require 'distribution'

RSpec.describe TrailGuide::Calculators::Bayesian do
  subject { described_class.new(experiment, probability, base: base, beta: beta).calculate! }
  let(:probability) { TrailGuide::Calculators::DEFAULT_PROBABILITY }
  let(:base) { :default }

  context 'when the integration gem is not available' do
    experiment
    before {
      TmpIntegration = Integration
      Object.send(:remove_const, :Integration)
    }
    after {
      Integration = TmpIntegration
      Object.send(:remove_const, :TmpIntegration)
    }

    it 'raises a NoIntegrationLibrary error' do
      expect { described_class.new(experiment) }.to raise_exception(TrailGuide::Calculators::NoIntegrationLibrary)
    end
  end

  context 'when using an unknown beta distribution library' do
    experiment
    let(:beta) { :foobar }

    it 'raises an UnknownBetaDistributionLibrary error' do
      expect { described_class.new(experiment, beta: beta) }.to raise_exception(TrailGuide::Calculators::UnknownBetaDistributionLibrary)
    end
  end

  context 'when using rubystats' do
    let(:beta) { :rubystats }

    context 'when the rubystats gem is not available' do
      experiment
      before {
        TmpRubystats = Rubystats
        Object.send(:remove_const, :Rubystats)
      }
      after {
        Rubystats = TmpRubystats
        Object.send(:remove_const, :TmpRubystats)
      }

      it 'raises a NoBetaDistributionLibrary error' do
        expect { described_class.new(experiment, beta: beta) }.to raise_exception(TrailGuide::Calculators::NoBetaDistributionLibrary)
      end
    end

    context 'with multiple variants' do
      experiment {
        variant :best
        variant :middle
        variant :worst
      }
      variant(:best)
      variant(:middle)
      variant(:worst)
      let(:measured) { OpenStruct.new(subject.variants.map { |var| [var.name, var] }.to_h) }

      context 'with evenly distributed participation' do
        before { experiment.variants.each { |var| var.adapter.increment(:participants, 1000) } }

        context 'with closely matched conversion rates' do
          before {
            best.adapter.increment(:converted, 255)
            middle.adapter.increment(:converted, 250)
            worst.adapter.increment(:converted, 245)
          }

          context 'with a low enough probability threshold' do
            let(:probability) { 10 }

            it 'chooses the best performing variant' do
              expect(subject.choice).to eq(subject.best)
            end
          end

          it 'does not choose a winning variant' do
            expect(subject.choice).to be_nil
          end

          it 'measures conversion' do
            expect(measured.best.superset).to   eq(1000)
            expect(measured.best.subset).to     eq(255)
            expect(measured.best.measure).to    eq(0.255)

            expect(measured.middle.superset).to eq(1000)
            expect(measured.middle.subset).to   eq(250)
            expect(measured.middle.measure).to  eq(0.25)

            expect(measured.worst.superset).to  eq(1000)
            expect(measured.worst.subset).to    eq(245)
            expect(measured.worst.measure).to   eq(0.245)
          end

          it 'calculates diffs' do
            expect(measured.best.difference).to   eq(2.0000000000000018)
            expect(measured.middle.difference).to eq(0)
            expect(measured.worst.difference).to  eq(-2.0000000000000018)
          end

          it 'calculates probabilities' do
            expect(measured.best.probability.to_s.split('e').first.to_f.round(10)).to    eq(49.1136765406)
            expect(measured.middle.probability.to_s.split('e').first.to_f.round(10)).to  eq(31.5911295377)
            expect(measured.worst.probability.to_s.split('e').first.to_f.round(10)).to   eq(19.2951939217)
          end

          it 'calculates significance' do
            expect(measured.best.significance).to   eq(10)
            expect(measured.middle.significance).to eq(10)
            expect(measured.worst.significance).to  eq(10)
          end
        end

        context 'with evenly stepped conversion rates' do
          before {
            best.adapter.increment(:converted, 750)
            middle.adapter.increment(:converted, 500)
            worst.adapter.increment(:converted, 250)
          }

          it 'chooses the best performing variant' do
            expect(subject.choice).to eq(subject.best)
          end

          it 'measures conversion' do
            expect(measured.best.superset).to   eq(1000)
            expect(measured.best.subset).to     eq(750)
            expect(measured.best.measure).to    eq(0.75)

            expect(measured.middle.superset).to eq(1000)
            expect(measured.middle.subset).to   eq(500)
            expect(measured.middle.measure).to  eq(0.5)

            expect(measured.worst.superset).to  eq(1000)
            expect(measured.worst.subset).to    eq(250)
            expect(measured.worst.measure).to   eq(0.25)
          end

          it 'calculates diffs' do
            expect(measured.best.difference).to   eq(50)
            expect(measured.middle.difference).to eq(0)
            expect(measured.worst.difference).to  eq(-50)
          end

          it 'calculates probabilities' do
            expect(measured.best.probability.to_s.split('e').first.to_f.round(10)).to    eq(100.0)
            expect(measured.middle.probability.to_s.split('e').first.to_f.round(10)).to  eq(1.5576922396)
            expect(measured.worst.probability.to_s.split('e').first.to_f.round(10)).to   eq(2.8945033977)
          end

          it 'calculates significance' do
            expect(measured.best.significance).to   eq(99.9)
            expect(measured.middle.significance).to eq(0)
            expect(measured.worst.significance).to  eq(0)
          end

          context 'when using the control as the base' do
            let(:base) { :control }

            it 'chooses the best performing variant' do
              expect(subject.choice).to eq(subject.best)
            end

            it 'measures conversion' do
              expect(measured.best.superset).to   eq(1000)
              expect(measured.best.subset).to     eq(750)
              expect(measured.best.measure).to    eq(0.75)

              expect(measured.middle.superset).to eq(1000)
              expect(measured.middle.subset).to   eq(500)
              expect(measured.middle.measure).to  eq(0.5)

              expect(measured.worst.superset).to  eq(1000)
              expect(measured.worst.subset).to    eq(250)
              expect(measured.worst.measure).to   eq(0.25)
            end

            it 'calculates diffs' do
              expect(measured.best.difference).to   eq(0)
              expect(measured.middle.difference).to eq(-33.33333333333333)
              expect(measured.worst.difference).to  eq(-66.66666666666666)
            end

            it 'calculates probabilities' do
              expect(measured.best.probability.to_s.split('e').first.to_f.round(10)).to    eq(100.0)
              expect(measured.middle.probability.to_s.split('e').first.to_f.round(10)).to  eq(1.5576922396)
              expect(measured.worst.probability.to_s.split('e').first.to_f.round(10)).to   eq(2.8945033977)
            end

            it 'calculates significance' do
              expect(measured.best.significance).to   eq(99.9)
              expect(measured.middle.significance).to eq(0)
              expect(measured.worst.significance).to  eq(0)
            end
          end
        end
      end
    end
  end

  context 'when using distribution' do
    let(:beta) { :distribution }

    context 'when the distribution gem is not available' do
      experiment
      before {
        TmpDistribution = Distribution
        Object.send(:remove_const, :Distribution)
      }
      after {
        Distribution = TmpDistribution
        Object.send(:remove_const, :TmpDistribution)
      }

      it 'raises a NoBetaDistributionLibrary error' do
        expect { described_class.new(experiment, beta: beta) }.to raise_exception(TrailGuide::Calculators::NoBetaDistributionLibrary)
      end
    end

    context 'with multiple variants' do
      experiment {
        variant :best
        variant :middle
        variant :worst
      }
      variant(:best)
      variant(:middle)
      variant(:worst)
      let(:measured) { OpenStruct.new(subject.variants.map { |var| [var.name, var] }.to_h) }

      context 'with evenly distributed participation' do
        before { experiment.variants.each { |var| var.adapter.increment(:participants, 1000) } }

        context 'with closely matched conversion rates' do
          before {
            best.adapter.increment(:converted, 255)
            middle.adapter.increment(:converted, 250)
            worst.adapter.increment(:converted, 245)
          }

          context 'with a low enough probability threshold' do
            let(:probability) { 10 }

            it 'chooses the best performing variant' do
              expect(subject.choice).to eq(subject.best)
            end
          end

          it 'does not choose a winning variant' do
            expect(subject.choice).to be_nil
          end

          it 'measures conversion' do
            expect(measured.best.superset).to eq(1000)
            expect(measured.best.subset).to   eq(255)
            expect(measured.best.measure).to  eq(0.255)

            expect(measured.middle.superset).to eq(1000)
            expect(measured.middle.subset).to   eq(250)
            expect(measured.middle.measure).to  eq(0.25)

            expect(measured.worst.superset).to  eq(1000)
            expect(measured.worst.subset).to    eq(245)
            expect(measured.worst.measure).to   eq(0.245)
          end

          it 'calculates diffs' do
            expect(measured.best.difference).to   eq(2.0000000000000018)
            expect(measured.middle.difference).to eq(0)
            expect(measured.worst.difference).to  eq(-2.0000000000000018)
          end

          it 'calculates probabilities' do
            expect(measured.best.probability.to_s.split('e').first.to_f.round(10)).to    eq(49.1136765407)
            expect(measured.middle.probability.to_s.split('e').first.to_f.round(10)).to  eq(31.5911295377)
            expect(measured.worst.probability.to_s.split('e').first.to_f.round(10)).to   eq(19.2951939217)
          end

          it 'calculates significance' do
            expect(measured.best.significance).to   eq(10)
            expect(measured.middle.significance).to eq(10)
            expect(measured.worst.significance).to  eq(10)
          end
        end

        context 'with evenly stepped conversion rates' do
          before {
            best.adapter.increment(:converted, 750)
            middle.adapter.increment(:converted, 500)
            worst.adapter.increment(:converted, 250)
          }

          it 'chooses the best performing variant' do
            expect(subject.choice).to eq(subject.best)
          end

          it 'measures conversion' do
            expect(measured.best.superset).to   eq(1000)
            expect(measured.best.subset).to     eq(750)
            expect(measured.best.measure).to    eq(0.75)

            expect(measured.middle.superset).to eq(1000)
            expect(measured.middle.subset).to   eq(500)
            expect(measured.middle.measure).to  eq(0.5)

            expect(measured.worst.superset).to  eq(1000)
            expect(measured.worst.subset).to    eq(250)
            expect(measured.worst.measure).to   eq(0.25)
          end

          it 'calculates diffs' do
            expect(measured.best.difference).to   eq(50)
            expect(measured.middle.difference).to eq(0)
            expect(measured.worst.difference).to  eq(-50)
          end

          it 'calculates probabilities' do
            expect(measured.best.probability.to_s.split('e').first.to_f.round(10)).to    eq(100.0)
            expect(measured.middle.probability.to_s.split('e').first.to_f.round(10)).to  eq(1.5576922396)
            expect(measured.worst.probability.to_s.split('e').first.to_f.round(10)).to   eq(2.8945033977)
          end

          it 'calculates significance' do
            expect(measured.best.significance).to   eq(99.9)
            expect(measured.middle.significance).to eq(0)
            expect(measured.worst.significance).to  eq(0)
          end

          context 'when using the control as the base' do
            let(:base) { :control }

            it 'chooses the best performing variant' do
              expect(subject.choice).to eq(subject.best)
            end

            it 'measures conversion' do
              expect(measured.best.superset).to   eq(1000)
              expect(measured.best.subset).to     eq(750)
              expect(measured.best.measure).to    eq(0.75)

              expect(measured.middle.superset).to eq(1000)
              expect(measured.middle.subset).to   eq(500)
              expect(measured.middle.measure).to  eq(0.5)

              expect(measured.worst.superset).to  eq(1000)
              expect(measured.worst.subset).to    eq(250)
              expect(measured.worst.measure).to   eq(0.25)
            end

            it 'calculates diffs' do
              expect(measured.best.difference).to   eq(0)
              expect(measured.middle.difference).to eq(-33.33333333333333)
              expect(measured.worst.difference).to  eq(-66.66666666666666)
            end

            it 'calculates probabilities' do
              expect(measured.best.probability.to_s.split('e').first.to_f.round(10)).to    eq(100.0)
              expect(measured.middle.probability.to_s.split('e').first.to_f.round(10)).to  eq(1.5576922396)
              expect(measured.worst.probability.to_s.split('e').first.to_f.round(10)).to   eq(2.8945033977)
            end

            it 'calculates significance' do
              expect(measured.best.significance).to   eq(99.9)
              expect(measured.middle.significance).to eq(0)
              expect(measured.worst.significance).to  eq(0)
            end
          end
        end
      end
    end
  end
end
