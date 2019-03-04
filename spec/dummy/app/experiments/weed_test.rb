class WeedTest < TrailGuide::Experiment
  variant :sativa
  variant :indica
  variant :hybrid

  algorithm :distributed

  goal :couch
  goal :work

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
