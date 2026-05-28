require "test_helper"

class ProjectApplicationBuildsControllerTest < ActionDispatch::IntegrationTest
  test "member can view build details" do
    app = Application.create!(
      project: projects(:one),
      name: "Build Details App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/build-details.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )
    build = Build.create!(
      application: app,
      requested_by: users(:one),
      status: "running",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "a" * 40,
      artifact_reference: "docker-container://10.0.0.48:2375/containers/container-123"
    )
    BuildPhaseEvent.create!(build: build, phase: "image_build", status: "running", message: "Container image build started", reported_at: Time.current)
    BuildLogChunk.create!(build: build, phase: "image_build", sequence: 1, chunk: "building image", reported_at: Time.current)
    BuildLogChunk.create!(build: build, phase: "image_build", sequence: 2, chunk: "stderr: [TRUNCATED] additional build output omitted", reported_at: Time.current)
    BuildHostRequestEvent.create!(
      build: build,
      request_method: "POST",
      request_path: "/containers/create",
      response_status_code: 201,
      duration_ms: 25,
      success: true
    )

    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    get project_application_build_url(projects(:one), app, build)

    assert_response :success
    assert_includes response.body, "Build details"
    assert_includes response.body, "Build host request status"
    assert_includes response.body, "building image"
    assert_includes response.body, "Logs were truncated due to size limits."
    assert_includes response.body, "data-controller=\"auto-refresh\""
    assert_includes response.body, "data-auto-refresh-enabled-value=\"true\""
    assert_includes response.body, "data-auto-refresh-target=\"label\""
    assert_includes response.body, "inline-flex items-center gap-1.5"
  end

  test "non-member cannot view build details" do
    app = Application.create!(
      project: projects(:one),
      name: "Build Details Forbidden App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/build-details-forbidden.git",
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

    post session_url, params: { session: { username: users(:two).username, password: "password123" } }

    get project_application_build_url(projects(:one), app, build)

    assert_response :forbidden
  end

  test "member can cancel a running build" do
    app = Application.create!(
      project: projects(:one),
      name: "Cancelable Build App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/cancelable-build.git",
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

    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    patch cancel_project_application_build_url(projects(:one), app, build)

    assert_redirected_to project_application_build_url(projects(:one), app, build)
    build.reload
    assert_equal "canceled", build.status
    assert_equal true, build.cancel_requested
  end

  test "non-member cannot cancel a build" do
    app = Application.create!(
      project: projects(:one),
      name: "Cancelable Build Forbidden App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/cancelable-build-forbidden.git",
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

    post session_url, params: { session: { username: users(:two).username, password: "password123" } }

    patch cancel_project_application_build_url(projects(:one), app, build)

    assert_response :forbidden
    build.reload
    assert_equal "running", build.status
  end

  test "canceling a terminal build shows alert" do
    app = Application.create!(
      project: projects(:one),
      name: "Terminal Build App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/terminal-build.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )
    build = Build.create!(
      application: app,
      requested_by: users(:one),
      status: "succeeded",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "a" * 40
    )

    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    patch cancel_project_application_build_url(projects(:one), app, build)

    assert_redirected_to project_application_build_url(projects(:one), app, build)
    follow_redirect!
    assert_includes response.body, "Build is already complete"
  end
end