experiment :basic_experiment do |config|
  variant :option_one, control: true
  variant :option_two
end

experiment :combined_experiment do |config|
  variant :option_a
  variant :option_b
  variant :option_c
  config.combined = [:first_combo, :last_combo]
end
