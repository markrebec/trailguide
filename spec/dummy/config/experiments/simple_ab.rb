experiment :simple_ab do |config|
  config.can_resume = true

  variant :alpha
  variant :bravo
end
