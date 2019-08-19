require 'rails_helper'
require 'shared_examples/participant_adapter'

RSpec.describe TrailGuide::Adapters::Participants::Anonymous do
  subject { described_class.new(nil) }

  it_behaves_like 'a participant adapter'
end
