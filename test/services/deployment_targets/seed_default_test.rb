require "test_helper"

class DeploymentTargetsSeedDefaultTest < ActiveSupport::TestCase
  test "creates the default deployment target idempotently" do
    DeploymentTarget.where(name: DeploymentTargets::SeedDefault::DEFAULT_NAME).delete_all

    assert_difference("DeploymentTarget.count", 1) do
      DeploymentTargets::SeedDefault.call
    end

    assert_no_difference("DeploymentTarget.count") do
      DeploymentTargets::SeedDefault.call
    end

    assert DeploymentTarget.exists?(name: DeploymentTargets::SeedDefault::DEFAULT_NAME)
  end
end
