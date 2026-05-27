require "test_helper"

class ApplicationsStartBuildTest < ActiveSupport::TestCase
  class FakeQueueJob
    cattr_accessor :calls, default: 0

    def self.perform_later
      self.calls += 1
    end
  end

  class FakeHeadCommitFetcher
    def self.call(endpoint_url:, repository_url:, auth_username:, auth_secret:)
      RepositoryConnections::FetchHeadCommit::Result.new(success?: true, commit_sha: "b" * 40)
    end
  end

  test "project member can request a build" do
    FakeQueueJob.calls = 0
    application = Application.create!(
      project: projects(:one),
      name: "Start Build App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/start-build.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    assert_difference("Build.count", 1) do
      assert_difference("AuditEvent.count", 1) do
        result = Applications::StartBuild.call(
          actor: users(:one),
          project: projects(:one),
          application: application,
          params: { source_ref: "main", commit_sha: "a" * 40 },
          queue_job: FakeQueueJob,
          head_commit_fetcher: FakeHeadCommitFetcher
        )

        assert result.success?
        assert_equal "pending", result.build.status
        assert_equal application, result.build.application
      end
    end

    assert_equal "build.requested", AuditEvent.order(:id).last.action
    assert_equal "a" * 40, application.reload.current_commit_sha
    assert_equal 1, FakeQueueJob.calls
  end

  test "non-member cannot request a build" do
    application = Application.create!(
      project: projects(:one),
      name: "Forbidden Build App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/forbidden-build.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    result = Applications::StartBuild.call(
      actor: users(:two),
      project: projects(:one),
      application: application,
      params: { source_ref: "main", commit_sha: "abc1234" },
      queue_job: FakeQueueJob,
      head_commit_fetcher: FakeHeadCommitFetcher
    )

    assert_not result.success?
    assert_equal :forbidden, result.error
  end

  test "resolves and persists repository HEAD commit when explicit commit is not provided" do
    FakeQueueJob.calls = 0
    application = Application.create!(
      project: projects(:one),
      name: "Resolved Head Commit App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/resolved-head.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    result = Applications::StartBuild.call(
      actor: users(:one),
      project: projects(:one),
      application: application,
      params: { source_ref: "main" },
      queue_job: FakeQueueJob,
      head_commit_fetcher: FakeHeadCommitFetcher
    )

    assert result.success?
    assert_equal "b" * 40, result.build.commit_sha
    assert_equal "b" * 40, application.reload.current_commit_sha
    assert_equal 1, FakeQueueJob.calls
  end
end
