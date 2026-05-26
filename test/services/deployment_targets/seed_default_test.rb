require "test_helper"

class DeploymentTargetsSeedDefaultTest < ActiveSupport::TestCase
  test "creates the default deployment target idempotently" do
    target = DeploymentTarget.find_by(name: DeploymentTargets::SeedDefault::DEFAULT_NAME)
    Environment.where(deployment_target: target).delete_all if target
    target&.destroy!

    assert_difference("DeploymentTarget.count", 1) do
      DeploymentTargets::SeedDefault.call
    end

    assert_no_difference("DeploymentTarget.count") do
      DeploymentTargets::SeedDefault.call
    end

    assert DeploymentTarget.exists?(name: DeploymentTargets::SeedDefault::DEFAULT_NAME)
  end
end
