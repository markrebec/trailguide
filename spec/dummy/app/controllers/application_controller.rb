class ApplicationController < ActionController::Base
  def current_user
    Struct.new(:id).new(1)
  end
end
