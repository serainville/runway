require "test_helper"

class DockerExecuteBuildTest < ActiveSupport::TestCase
  class FakeHttpSuccess
    def self.call(method:, uri:, body: nil)
      if uri.path.include?("/images/create")
        Struct.new(:code, :body).new("200", "{}")
      elsif uri.path.include?("/containers/create")
        Struct.new(:code, :body).new("201", "{\"Id\":\"container-123\"}")
      else
        Struct.new(:code, :body).new("204", "")
      end
    end
  end

  class FakeHttpCreateNotFound
    def self.call(method:, uri:, body: nil)
      if uri.path.include?("/images/create")
        Struct.new(:code, :body).new("200", "{}")
      elsif uri.path.include?("/containers/create")
        Struct.new(:code, :body).new("404", "{\"message\":\"No such image: alpine:3.20\"}")
      else
        Struct.new(:code, :body).new("204", "")
      end
    end
  end

  class FakeHttpPullFailure
    def self.call(method:, uri:, body: nil)
      Struct.new(:code, :body).new("500", "{\"message\":\"registry timeout\"}")
    end
  end

  test "starts build container successfully" do
    app = Application.create!(
      project: projects(:one),
      name: "Docker Execute Success App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/docker-execute-success.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )
    build = Build.create!(
      application: app,
      requested_by: users(:one),
      status: "running",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "abc1234"
    )

    result = Docker::ExecuteBuild.call(endpoint: "http://docker.example.com:2375", build: build, http_runner: FakeHttpSuccess)

    assert result.success?
    assert_equal "container-123", result.container_id
    assert_equal "running", result.runtime_status
    assert_equal 3, result.request_events.size
    assert_equal "/images/create", result.request_events.first[:request_path]
  end

  test "fails when docker container cannot be created" do
    app = Application.create!(
      project: projects(:one),
      name: "Docker Execute Failure App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/docker-execute-failure.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )
    build = Build.create!(
      application: app,
      requested_by: users(:one),
      status: "running",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "abc1234"
    )

    result = Docker::ExecuteBuild.call(endpoint: "http://docker.example.com:2375", build: build, http_runner: FakeHttpCreateNotFound)

    assert_not result.success?
    assert_equal :container_create_failed, result.error
    assert_equal 2, result.request_events.size
    assert_equal "No such image: alpine:3.20", result.request_events.last[:error_message]
  end

  test "fails when builder image cannot be pulled" do
    app = Application.create!(
      project: projects(:one),
      name: "Docker Pull Failure App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/docker-pull-failure.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )
    build = Build.create!(
      application: app,
      requested_by: users(:one),
      status: "running",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "abc1234"
    )

    result = Docker::ExecuteBuild.call(endpoint: "http://docker.example.com:2375", build: build, http_runner: FakeHttpPullFailure)

    assert_not result.success?
    assert_equal :image_pull_failed, result.error
    assert_equal 1, result.request_events.size
    assert_equal "registry timeout", result.request_events.first[:error_message]
  end
end