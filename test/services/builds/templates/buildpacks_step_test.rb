require "test_helper"

class BuildsTemplatesBuildpacksStepTest < ActiveSupport::TestCase
  FIXTURE_IMAGE = "nexus/apps/acme/myapp:sha-abc123"

  test "returns a step hash with name 'build'" do
    step = Builds::Templates::BuildpacksStep.call(artifact_image: FIXTURE_IMAGE)

    assert_equal "build", step[:name]
  end

  test "step command contains pack build" do
    step = Builds::Templates::BuildpacksStep.call(artifact_image: FIXTURE_IMAGE)

    assert step[:command].include?("pack"), "expected command to include 'pack'"
    assert step[:command].include?("build"), "expected command to include 'build'"
    assert step[:command].include?("--publish"), "expected command to include '--publish'"
  end

  test "step command specifies a builder image" do
    step = Builds::Templates::BuildpacksStep.call(artifact_image: FIXTURE_IMAGE)

    assert step[:command].include?("--builder"), "expected command to include '--builder'"
  end

  test "step command includes the artifact image tag" do
    step = Builds::Templates::BuildpacksStep.call(artifact_image: FIXTURE_IMAGE)

    assert step[:command].include?(FIXTURE_IMAGE), "expected command to include artifact image reference"
  end

  test "step has a timeout_seconds value" do
    step = Builds::Templates::BuildpacksStep.call(artifact_image: FIXTURE_IMAGE)

    assert step[:timeout_seconds].is_a?(Integer)
    assert step[:timeout_seconds] > 0
  end
end
