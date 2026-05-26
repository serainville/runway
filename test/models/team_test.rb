require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "requires name" do
    team = Team.new

    assert_not team.valid?
    assert_includes team.errors[:name], "can't be blank"
  end
end
