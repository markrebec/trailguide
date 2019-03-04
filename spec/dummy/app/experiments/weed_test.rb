class WeedTest < TrailGuide::Experiment
  variant :sativa
  variant :indica
  variant :hybrid

  algorithm :distributed

  goal :couch
  goal :work
end
