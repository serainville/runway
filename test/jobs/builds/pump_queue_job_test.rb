require "test_helper"

class BuildsPumpQueueJobTest < ActiveJob::TestCase
  class FakeDispatcher
    cattr_accessor :calls, default: 0

    def self.call(build:)
      self.calls += 1
      build.update!(status: "succeeded")
      Builds::DispatchPending::Result.new(success?: true, build: build)
    end
  end

  test "dispatches pending builds asynchronously" do
    FakeDispatcher.calls = 0
    app = Application.create!(
      project: projects(:one),
      name: "Pump Queue App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/pump-queue.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )
    build = Build.create!(
      application: app,
      requested_by: users(:one),
      status: "pending",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "a" * 40
    )

    Builds::PumpQueueJob.perform_now(dispatcher: FakeDispatcher, requeue: false)

    assert_equal 1, FakeDispatcher.calls
    assert_equal "succeeded", build.reload.status
  end
end
