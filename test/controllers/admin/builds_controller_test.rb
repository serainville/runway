require "test_helper"

module Admin
  class BuildsControllerTest < ActionDispatch::IntegrationTest
    test "redirects unauthenticated users" do
      get admin_builds_url

      assert_redirected_to new_session_url
    end

    test "forbids non-admin users" do
      post session_url, params: { session: { username: users(:one).username, password: "password123" } }

      get admin_builds_url

      assert_response :forbidden
    end

    test "admin can view build queue" do
      app = Application.create!(
        project: projects(:one),
        name: "Queue Visibility App",
        runtime: "ruby",
        runtime_version: "4",
        repository_url: "https://gitlab.example.com/tenant/queue-visibility.git",
        repository_connection: repository_connections(:project_one_gitlab)
      )
      Build.create!(
        application: app,
        requested_by: users(:one),
        status: "pending",
        runtime_key: "ruby-4",
        source_ref: "main",
        commit_sha: "abc1234"
      )

      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      get admin_builds_url

      assert_response :success
      assert_includes response.body, "Admin Build Queue"
      assert_includes response.body, "Queue Visibility App"
      assert_includes response.body, "Pending"
      assert_includes response.body, "Build details"
      assert_includes response.body, "data-controller=\"auto-refresh\""
      assert_includes response.body, "data-auto-refresh-enabled-value=\"true\""
      assert_includes response.body, "data-auto-refresh-target=\"label\""
      assert_includes response.body, "inline-flex items-center gap-1.5"
    end

    test "admin can view build details" do
      app = Application.create!(
        project: projects(:one),
        name: "Admin Build Details App",
        runtime: "ruby",
        runtime_version: "4",
        repository_url: "https://gitlab.example.com/tenant/admin-build-details.git",
        repository_connection: repository_connections(:project_one_gitlab)
      )
      build = Build.create!(
        application: app,
        requested_by: users(:one),
        status: "succeeded",
        runtime_key: "ruby-4",
        source_ref: "main",
        commit_sha: "a" * 40,
        artifact_reference: "docker-container://10.0.0.48:2375/containers/container-123",
        runtime_container_id: "container-123",
        runtime_status: "running"
      )
      BuildLogChunk.create!(build: build, phase: "image_build", sequence: 1, chunk: "docker build output", reported_at: Time.current)
      BuildLogChunk.create!(build: build, phase: "image_build", sequence: 2, chunk: "stderr: [TRUNCATED] additional build output omitted", reported_at: Time.current)

      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      get admin_build_url(build)

      assert_response :success
      assert_includes response.body, "Build details"
      assert_includes response.body, "container-123"
      assert_includes response.body, "Build logs"
      assert_includes response.body, "Logs were truncated due to size limits."
      assert_includes response.body, "data-controller=\"auto-refresh\""
      assert_includes response.body, "data-auto-refresh-enabled-value=\"false\""
      assert_includes response.body, "data-auto-refresh-target=\"label\""
    end
  end
end