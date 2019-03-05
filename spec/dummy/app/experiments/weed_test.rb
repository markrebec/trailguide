class WeedTest < TrailGuide::Experiment
  experiment_name :types_of_weed

  variant :sativa
  variant :indica
  variant :hybrid

  algorithm :distributed

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
