require "test_helper"

class DeploymentTargetTest < ActiveSupport::TestCase
  test "requires unique name" do
    duplicate = DeploymentTarget.new(name: deployment_targets(:one).name)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end
end
