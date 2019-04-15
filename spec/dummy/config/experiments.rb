experiment :basic_experiment do |config|
  config.summary = "simple A/B test showing off some basic configuration"

  config.metric = :example_metric

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

  config.combined = [:login_button_color, :signup_button_color]

  config.target_sample_size = 100
end
