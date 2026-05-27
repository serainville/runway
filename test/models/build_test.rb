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
end
