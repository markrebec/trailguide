class WeedTest < TrailGuide::Experiment
  configure do |config|
    config.name = :types_of_weed
    config.algorithm = :distributed
    config.metric = :stoner
    config.reset_manually = true
    config.start_manually = true
    config.store_override = false
    config.track_override = false

    variant :sativa
    variant :indica, control: true
    variant :hybrid
    config.control = :hybrid

    goal :sat_on_couch
    goal :got_work_done
    goal :cleaned_the_house

    on_choose do |experiment, variant, metadata|
      ap "ON CHOOSE"
      ap experiment.experiment_name
      ap variant.name
      ap metadata
    end

    on_use do |experiment, variant, metadata|
      ap "ON USE"
      ap experiment.experiment_name
      ap variant.name
      ap metadata
    end

    on_convert do |experiment, variant, checkpoint, metadata|
      ap "ON CONVERT"
      ap experiment.experiment_name
      ap variant.name
      ap checkpoint
      ap metadata
    end
  end
end

class WeedSubTest < WeedTest
  configure do
    on_start do |experiment|
      puts "STARTING"
    end
  end
end
