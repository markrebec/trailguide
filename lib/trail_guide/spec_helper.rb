module TrailGuide
  module SpecHelper

    def use_trailguide(**experiments, &block)
      if block_given?
        before do
          use_trailguide(**experiments)
        end

        yield
      else
        experiments.each do |exp,var|
          experiment = TrailGuide.catalog.find(exp)
          raise ArgumentError, "Experiment not found `#{exp}`" unless experiment.present?
          variant = experiment.variants.find { |v| v == var }
          raise ArgumentError, "Variant `#{var}` not found in experiment `#{exp}`" unless variant.present?

          allow_any_instance_of(experiment).to receive(:choose!).and_return(variant)
        end
      end
    end
    alias_method :with_trailguide, :use_trailguide
  end
end

if defined?(RSpec)
  RSpec.configure do |config|
    config.extend  TrailGuide::SpecHelper
    config.include TrailGuide::SpecHelper
  end
end
