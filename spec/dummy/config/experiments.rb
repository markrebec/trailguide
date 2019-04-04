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

experiment :button_color do |config|
  variant :green
  variant :blue
  variant :white, control: true

  config.combined = [:login_button_color, :signup_button_color]

  config.target_sample_size = 100
end
