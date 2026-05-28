require "test_helper"

class BuildsClaimNextBuildTest < ActiveSupport::TestCase
  test "claims oldest pending build and assigns lease" do
    application = Application.create!(
      project: projects(:one),
      name: "Claim Build App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/claim-build.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    build = Build.create!(
      application: application,
      requested_by: users(:one),
      status: "pending",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "abc1234"
    )

    result = Builds::ClaimNextBuild.call(worker_id: "docker-host-01", capabilities: { runtimes: ["ruby-4"] })

    assert result.success?
    assert_equal build.id, result.build.id
    assert_equal "running", result.build.reload.status
    assert result.build.lease_id.present?
    assert_equal "docker-host-01", result.build.worker_id
  end
end
