require "test_helper"

class BuildTest < ActiveSupport::TestCase
  test "valid build with required fields" do
    application = Application.create!(
      project: projects(:one),
      name: "Buildable App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/buildable.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    build = Build.new(
      application: application,
      requested_by: users(:one),
      status: "pending",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "abcdef1"
    )

    assert build.valid?
  end

  test "invalid without required runtime key" do
    application = Application.create!(
      project: projects(:one),
      name: "Missing Runtime Key App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/missing-runtime-key.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    build = Build.new(
      application: application,
      requested_by: users(:one),
      source_ref: "main",
      commit_sha: "abcdef1"
    )

    assert_not build.valid?
    assert_includes build.errors[:runtime_key], "can't be blank"
  end

  test "invalid with unsupported status" do
    application = Application.create!(
      project: projects(:one),
      name: "Invalid Status App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/invalid-status.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    build = Build.new(application: application, requested_by: users(:one), status: "unknown", runtime_key: "ruby-4", source_ref: "main", commit_sha: "abcdef1")

    assert_not build.valid?
    assert_includes build.errors[:status], "is not included in the list"
  end

  test "parses repository URL, image name, and tag from artifact reference" do
    build = builds_for_artifact_parsing(artifact_reference: "nexus.serverlab.intra/apps/plato/rails-demo-app:sha-abc123")

    assert_equal "nexus.serverlab.intra/apps/plato", build.container_repository_url
    assert_equal "rails-demo-app", build.container_image_name
    assert_equal "sha-abc123", build.container_tag_or_hash
  end

  test "uses digest hash when artifact reference has no tag" do
    build = builds_for_artifact_parsing(artifact_reference: "nexus.serverlab.intra/apps/plato/rails-demo-app@sha256:0123456789abcdef")

    assert_equal "nexus.serverlab.intra/apps/plato", build.container_repository_url
    assert_equal "rails-demo-app", build.container_image_name
    assert_equal "sha256:0123456789abcdef", build.container_tag_or_hash
  end

  test "falls back to commit hash when artifact reference has no tag or digest" do
    build = builds_for_artifact_parsing(
      artifact_reference: "nexus.serverlab.intra/apps/plato/rails-demo-app",
      commit_sha: "1234567890abcdef1234567890abcdef12345678"
    )

    assert_equal "nexus.serverlab.intra/apps/plato", build.container_repository_url
    assert_equal "rails-demo-app", build.container_image_name
    assert_equal "1234567890abcdef1234567890abcdef12345678", build.container_tag_or_hash
  end

  private

  def builds_for_artifact_parsing(artifact_reference:, commit_sha: "abcdef1234567890abcdef1234567890abcdef12")
    application = Application.create!(
      project: projects(:one),
      name: "Artifact Parsing App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/artifact-parsing.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    Build.create!(
      application: application,
      requested_by: users(:one),
      status: "succeeded",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: commit_sha,
      artifact_reference: artifact_reference
    )
  end
end
