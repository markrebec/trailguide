experiment :basic_experiment do |config|
  config.summary = "simple A/B test showing off some basic configuration"
  config.track_winner_conversions = true

  config.group = :example_group

  variant :option_one, control: true
  variant :option_two

  config.target_sample_size = 500

  rollout_winner do |experiment, winner|
    puts "RETURNING SAMPLE"
    [experiment.control, winner].sample
  end
end

experiment :non_resumable_experiment do |config|
  config.summary = "experiment that cannot be paused or resumed"

  config.groups = [:example_group, :other_group]

  variant :control
  variant :alternative

  on_start do |experiment, context|
    puts "ON START #{experiment.experiment_name}"
  end

  on_stop do |experiment, context|
    puts "ON STOP #{experiment.experiment_name}"
  end

  on_pause do |experiment, context|
    puts "ON PAUSE #{experiment.experiment_name}"
  end

  on_resume do |experiment, context|
    puts "ON RESUME #{experiment.experiment_name}"
  end

  on_reset do |experiment, context|
    puts "ON RESET #{experiment.experiment_name}"
  end
end

experiment :resumable_experiment do |config|
  config.summary = "experiment that can be paused and resumed"
  config.can_resume = true

  variant :control
  variant :alternative

  #config.combined = [:alpha_resume, :beta_resume]

  on_start do |experiment, context|
    puts "ON START #{experiment.experiment_name}"
  end

  on_stop do |experiment, context|
    puts "ON STOP #{experiment.experiment_name}"
  end

  on_pause do |experiment, context|
    puts "ON PAUSE #{experiment.experiment_name}"
  end

  on_resume do |experiment, context|
    puts "ON RESUME #{experiment.experiment_name}"
  end

  on_reset do |experiment, context|
    puts "ON RESET #{experiment.experiment_name}"
  end
end

experiment :button_color do |config|
  config.summary = "example combined experiment"

  variant :green
  variant :blue
  variant :white, control: true

  config.groups = [:first, :second]
  config.goals = [:first, :second]
  config.combined = [:login_button_color, :signup_button_color]

  config.target_sample_size = 100
end

experiment :multi_goal_example do |config|
  config.summary = "example experiment with multiple goals"
  config.algorithm = :distributed

  variant :green
  variant :blue
  variant :white, control: true
  variant :red
  variant :black

  config.groups = [:first, :second]
  config.goals = [:first, :second]

  config.enable_calibration = true
  config.target_sample_size = 100
end

experiment :long_description do |config|
  config.summary = "Example experiment with a really long description to test formatting/UI. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus vulputate eros quis ultricies tincidunt. Aliquam magna nunc, semper vitae enim non, aliquet congue velit. Sed placerat dolor in mauris blandit placerat. Suspendisse et est leo. Aliquam erat volutpat. Fusce ac nibh nulla. Morbi commodo efficitur scelerisque. Aenean pellentesque ante vitae elit sodales ultricies. Suspendisse lacinia nisi sed suscipit scelerisque."

  variant :alpha
  variant :bravo
  variant :charlie

  config.enable_calibration = true
  config.track_winner_conversions = true
  config.allow_multiple_conversions = true
end
