require "test_helper"

class BuildHostRequestEventTest < ActiveSupport::TestCase
  test "requires method path and status code" do
    app = Application.create!(
      project: projects(:one),
      name: "Host Request Event App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/host-event.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )
    build = Build.create!(
      application: app,
      requested_by: users(:one),
      status: "running",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "a" * 40
    )

    event = BuildHostRequestEvent.new(
      build: build,
      request_method: "",
      request_path: "",
      response_status_code: nil,
      success: true
    )

    assert_not event.valid?
    assert_includes event.errors[:request_method], "can't be blank"
    assert_includes event.errors[:request_path], "can't be blank"
    assert_includes event.errors[:response_status_code], "can't be blank"
  end
end