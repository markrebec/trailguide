require "trail_guide/algorithms/algorithm"
require "trail_guide/algorithms/weighted"
require "trail_guide/algorithms/distributed"
require "trail_guide/algorithms/bandit"
require "trail_guide/algorithms/random"
require "trail_guide/algorithms/static"

module TrailGuide
  module Algorithms
    def self.algorithm(algo)
      case algo
      when :weighted
        algo = TrailGuide::Algorithms::Weighted
      when :bandit
        algo = TrailGuide::Algorithms::Bandit
      when :distributed
        algo = TrailGuide::Algorithms::Distributed
      when :random
        algo = TrailGuide::Algorithms::Random
      when :static
        algo = TrailGuide::Algorithms::Static
      else
        algo = algo.constantize if algo.is_a?(String)
      end
      algo
    end
  end
end
