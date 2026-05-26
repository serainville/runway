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

  test "requires deployment target" do
    environment = Environment.new(application: applications(:one), name: "nonp", default: true)

    assert_not environment.valid?
    assert_includes environment.errors[:deployment_target], "must exist"
  end

  test "enforces unique name per application" do
    duplicate = Environment.new(
      application: environments(:one).application,
      deployment_target: deployment_targets(:one),
      name: environments(:one).name,
      default: false
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end
end
