require "test_helper"

class BuildsTemplatesBuildkitStepTest < ActiveSupport::TestCase
  FIXTURE_IMAGE = "nexus/apps/acme/myapp:sha-abc123"

  test "returns a step hash with name 'build'" do
    step = Builds::Templates::BuildkitStep.call(artifact_image: FIXTURE_IMAGE)

    assert_equal "build", step[:name]
  end

  test "step command contains docker buildx build" do
    step = Builds::Templates::BuildkitStep.call(artifact_image: FIXTURE_IMAGE)

    assert step[:command].include?("docker"), "expected command to include 'docker'"
    assert step[:command].include?("buildx"), "expected command to include 'buildx'"
    assert step[:command].include?("build"), "expected command to include 'build'"
    assert step[:command].include?("--push"), "expected command to include '--push'"
  end

  test "step command includes platform flag" do
    step = Builds::Templates::BuildkitStep.call(artifact_image: FIXTURE_IMAGE)

    assert step[:command].include?("--platform"), "expected command to include '--platform'"
    assert step[:command].include?("linux/amd64"), "expected command to include 'linux/amd64'"
  end

  test "step command includes the artifact image tag" do
    step = Builds::Templates::BuildkitStep.call(artifact_image: FIXTURE_IMAGE)

    assert step[:command].include?(FIXTURE_IMAGE), "expected command to include artifact image reference"
  end

  test "step has a timeout_seconds value" do
    step = Builds::Templates::BuildkitStep.call(artifact_image: FIXTURE_IMAGE)

    assert step[:timeout_seconds].is_a?(Integer)
    assert step[:timeout_seconds] > 0
  end
end
