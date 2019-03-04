class HomepageController < ApplicationController
  def index
    trailguide.choose!(:weed_test) do |variant|
      ap variant.to_s
    end
    trailguide.run!(:weed_test)
    #trailguide.render!(:weed_test)
  end

  def sativa
    ap "SATIVA"
  end

  def indica
    ap "INDICA"
  end

  def hybrid
    ap "HYBRID"
  end
end
