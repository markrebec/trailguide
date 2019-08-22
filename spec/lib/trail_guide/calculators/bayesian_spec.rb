require 'rails_helper'
require 'integration'
require 'rubystats'
require 'distribution'

RSpec.describe TrailGuide::Calculators::Bayesian do
  subject { described_class.new(experiment, probability, base: base, beta: beta).calculate! }
  let(:probability) { TrailGuide::Calculators::DEFAULT_PROBABILITY }
  let(:base) { :default }

  context 'when using rubystats' do
    let(:beta) { :rubystats }

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
            expect(measured.best.subset).to eq(255)
            expect(measured.best.measure).to eq(0.255)

            expect(measured.middle.superset).to eq(1000)
            expect(measured.middle.subset).to eq(250)
            expect(measured.middle.measure).to eq(0.25)

            expect(measured.worst.superset).to eq(1000)
            expect(measured.worst.subset).to eq(245)
            expect(measured.worst.measure).to eq(0.245)
          end

          it 'calculates diffs' do
            expect(measured.best.difference).to eq(2.0000000000000018)
            expect(measured.middle.difference).to eq(0)
            expect(measured.worst.difference).to eq(-2.0000000000000018)
          end

          it 'calculates probabilities' do
            expect(measured.best.probability).to eq(49.11367654062689)
            expect(measured.middle.probability).to eq(31.591129537662212)
            expect(measured.worst.probability).to eq(19.29519392166465)
          end

          it 'calculates significance' do
            expect(measured.best.significance).to eq(10)
            expect(measured.middle.significance).to eq(10)
            expect(measured.worst.significance).to eq(10)
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
            expect(measured.best.superset).to eq(1000)
            expect(measured.best.subset).to eq(750)
            expect(measured.best.measure).to eq(0.75)

            expect(measured.middle.superset).to eq(1000)
            expect(measured.middle.subset).to eq(500)
            expect(measured.middle.measure).to eq(0.5)

            expect(measured.worst.superset).to eq(1000)
            expect(measured.worst.subset).to eq(250)
            expect(measured.worst.measure).to eq(0.25)
          end

          it 'calculates diffs' do
            expect(measured.best.difference).to eq(50)
            expect(measured.middle.difference).to eq(0)
            expect(measured.worst.difference).to eq(-50)
          end

          it 'calculates probabilities' do
            expect(measured.best.probability).to eq(99.99999999998965)
            expect(measured.middle.probability).to eq(1.557692239575977e-29)
            expect(measured.worst.probability).to eq(2.8945033977069632e-114)
          end

          it 'calculates significance' do
            expect(measured.best.significance).to eq(99.9)
            expect(measured.middle.significance).to eq(0)
            expect(measured.worst.significance).to eq(0)
          end

          context 'when using the control as the base' do
            let(:base) { :control }

            it 'chooses the best performing variant' do
              expect(subject.choice).to eq(subject.best)
            end

            it 'measures conversion' do
              expect(measured.best.superset).to eq(1000)
              expect(measured.best.subset).to eq(750)
              expect(measured.best.measure).to eq(0.75)

              expect(measured.middle.superset).to eq(1000)
              expect(measured.middle.subset).to eq(500)
              expect(measured.middle.measure).to eq(0.5)

              expect(measured.worst.superset).to eq(1000)
              expect(measured.worst.subset).to eq(250)
              expect(measured.worst.measure).to eq(0.25)
            end

            it 'calculates diffs' do
              expect(measured.best.difference).to eq(0)
              expect(measured.middle.difference).to eq(-33.33333333333333)
              expect(measured.worst.difference).to eq(-66.66666666666666)
            end

            it 'calculates probabilities' do
              expect(measured.best.probability).to eq(99.99999999998965)
              expect(measured.middle.probability).to eq(1.557692239575977e-29)
              expect(measured.worst.probability).to eq(2.8945033977069632e-114)
            end

            it 'calculates significance' do
              expect(measured.best.significance).to eq(99.9)
              expect(measured.middle.significance).to eq(0)
              expect(measured.worst.significance).to eq(0)
            end
          end
        end
      end
    end
  end

  context 'when using distribution' do
    let(:beta) { :distribution }

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
            expect(measured.best.subset).to eq(255)
            expect(measured.best.measure).to eq(0.255)

            expect(measured.middle.superset).to eq(1000)
            expect(measured.middle.subset).to eq(250)
            expect(measured.middle.measure).to eq(0.25)

            expect(measured.worst.superset).to eq(1000)
            expect(measured.worst.subset).to eq(245)
            expect(measured.worst.measure).to eq(0.245)
          end

          it 'calculates diffs' do
            expect(measured.best.difference).to eq(2.0000000000000018)
            expect(measured.middle.difference).to eq(0)
            expect(measured.worst.difference).to eq(-2.0000000000000018)
          end

          it 'calculates probabilities' do
            expect(measured.best.probability).to eq(49.113676540671456)
            expect(measured.middle.probability).to eq(31.59112953766277)
            expect(measured.worst.probability).to eq(19.295193921665877)
          end

          it 'calculates significance' do
            expect(measured.best.significance).to eq(10)
            expect(measured.middle.significance).to eq(10)
            expect(measured.worst.significance).to eq(10)
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
            expect(measured.best.superset).to eq(1000)
            expect(measured.best.subset).to eq(750)
            expect(measured.best.measure).to eq(0.75)

            expect(measured.middle.superset).to eq(1000)
            expect(measured.middle.subset).to eq(500)
            expect(measured.middle.measure).to eq(0.5)

            expect(measured.worst.superset).to eq(1000)
            expect(measured.worst.subset).to eq(250)
            expect(measured.worst.measure).to eq(0.25)
          end

          it 'calculates diffs' do
            expect(measured.best.difference).to eq(50)
            expect(measured.middle.difference).to eq(0)
            expect(measured.worst.difference).to eq(-50)
          end

          it 'calculates probabilities' do
            expect(measured.best.probability).to eq(100.00000000001239)
            expect(measured.middle.probability).to eq(1.5576922395773937e-29)
            expect(measured.worst.probability).to eq(2.8945033977069372e-114)
          end

          it 'calculates significance' do
            expect(measured.best.significance).to eq(99.9)
            expect(measured.middle.significance).to eq(0)
            expect(measured.worst.significance).to eq(0)
          end

          context 'when using the control as the base' do
            let(:base) { :control }

            it 'chooses the best performing variant' do
              expect(subject.choice).to eq(subject.best)
            end

            it 'measures conversion' do
              expect(measured.best.superset).to eq(1000)
              expect(measured.best.subset).to eq(750)
              expect(measured.best.measure).to eq(0.75)

              expect(measured.middle.superset).to eq(1000)
              expect(measured.middle.subset).to eq(500)
              expect(measured.middle.measure).to eq(0.5)

              expect(measured.worst.superset).to eq(1000)
              expect(measured.worst.subset).to eq(250)
              expect(measured.worst.measure).to eq(0.25)
            end

            it 'calculates diffs' do
              expect(measured.best.difference).to eq(0)
              expect(measured.middle.difference).to eq(-33.33333333333333)
              expect(measured.worst.difference).to eq(-66.66666666666666)
            end

            it 'calculates probabilities' do
              expect(measured.best.probability).to eq(100.00000000001239)
              expect(measured.middle.probability).to eq(1.5576922395773937e-29)
              expect(measured.worst.probability).to eq(2.8945033977069372e-114)
            end

            it 'calculates significance' do
              expect(measured.best.significance).to eq(99.9)
              expect(measured.middle.significance).to eq(0)
              expect(measured.worst.significance).to eq(0)
            end
          end
        end
      end
    end
  end
end
