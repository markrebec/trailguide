experiment :basic_experiment do |config|
  config.metric = :homepage_search

  variant :option_one, control: true
  variant :option_two

  config.target_sample_size = 500

  rollout_winner do |experiment, winner|
    puts "RETURNING SAMPLE"
    [experiment.control, winner].sample
  end
end

experiment :combined_experiment do |config|
  variant :option_a
  variant :option_b
  variant :option_c, control: true
  config.goals = [:some_goal, :other_goal]
  config.combined = [:first_combo, :last_combo]

  config.target_sample_size = 100
end
