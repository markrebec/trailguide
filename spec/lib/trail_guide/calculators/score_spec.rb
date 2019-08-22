require 'rails_helper'

RSpec.describe TrailGuide::Calculators::Score do
  subject { described_class.new(experiment, probability, base: base).calculate! }
  let(:probability) { TrailGuide::Calculators::DEFAULT_PROBABILITY }
  let(:base) { :default }

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
          let(:probability) { 50 }

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

        it 'calculates z-scores' do
          expect(measured.best.z_score).to    eq(0.25735102802579907)
          expect(measured.middle.z_score).to  eq(0)
          expect(measured.worst.z_score).to   eq(-0.25907257393182725)
        end

        it 'calculates diffs' do
          expect(measured.best.difference).to   eq(2.0000000000000018)
          expect(measured.middle.difference).to eq(0)
          expect(measured.worst.difference).to  eq(-2.0000000000000018)
        end

        it 'calculates probabilities' do
          expect(measured.best.probability.to_s.split('e').first.to_f.round(10)).to   eq(60.2)
          expect(measured.middle.probability.to_s.split('e').first.to_f.round(10)).to eq(50.3000000000)
          expect(measured.worst.probability.to_s.split('e').first.to_f.round(10)).to  eq(-60.2)
        end

        it 'calculates significance' do
          expect(measured.best.significance).to   eq(50)
          expect(measured.middle.significance).to eq(50)
          expect(measured.worst.significance).to  eq(-50)
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

        it 'calculates z-scores' do
          expect(measured.best.z_score).to    eq(11.952286093343936)
          expect(measured.middle.z_score).to  eq(0)
          expect(measured.worst.z_score).to   eq(-11.952286093343936)
        end

        it 'calculates diffs' do
          expect(measured.best.difference).to   eq(50)
          expect(measured.middle.difference).to eq(0)
          expect(measured.worst.difference).to  eq(-50)
        end

        it 'calculates probabilities' do
          expect(measured.best.probability.to_s.split('e').first.to_f.round(10)).to   eq(100)
          expect(measured.middle.probability.to_s.split('e').first.to_f.round(10)).to eq(50.3000000000)
          expect(measured.worst.probability.to_s.split('e').first.to_f.round(10)).to  eq(-100)
        end

        it 'calculates significance' do
          expect(measured.best.significance).to   eq(99.9)
          expect(measured.middle.significance).to eq(50)
          expect(measured.worst.significance).to  eq(-99.9)
        end

        context 'when using the control as the base' do
          let(:base) { :control }

          context 'when the probability threshold is low enough' do
            let(:probability) { 50 }

            it 'chooses the best performing variant' do
              expect(subject.choice).to eq(subject.best)
            end
          end

          it 'does not choose a winning variant' do
            expect(subject.choice).to be_nil
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

          it 'calculates z-scores' do
            expect(measured.best.z_score).to    eq(0)
            expect(measured.middle.z_score).to  eq(-11.952286093343936)
            expect(measured.worst.z_score).to   eq(-25.81988897471611)
          end

          it 'calculates diffs' do
            expect(measured.best.difference).to   eq(0)
            expect(measured.middle.difference).to eq(-33.33333333333333)
            expect(measured.worst.difference).to  eq(-66.66666666666666)
          end

          it 'calculates probabilities' do
            expect(measured.best.probability.to_s.split('e').first.to_f.round(10)).to   eq(50.3000000000)
            expect(measured.middle.probability.to_s.split('e').first.to_f.round(10)).to eq(-100)
            expect(measured.worst.probability.to_s.split('e').first.to_f.round(10)).to  eq(-100)
          end

          it 'calculates significance' do
            expect(measured.best.significance).to   eq(50)
            expect(measured.middle.significance).to eq(-99.9)
            expect(measured.worst.significance).to  eq(-99.9)
          end
        end
      end
    end
  end
end
