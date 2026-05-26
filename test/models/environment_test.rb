require "test_helper"

class EnvironmentTest < ActiveSupport::TestCase
  test "requires name" do
    environment = Environment.new(application: applications(:one), default: false)

    assert_not environment.valid?
    assert_includes environment.errors[:name], "can't be blank"
  end

  test "requires default to be boolean" do
    environment = Environment.new(application: applications(:one), name: "preview", default: nil)

    assert_not environment.valid?
    assert_includes environment.errors[:default], "is not included in the list"
  end
end
