require "test_helper"

class ProjectApplicationsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated users from project applications" do
    get project_applications_url(projects(:one))

    assert_redirected_to new_session_url
  end

  test "allows member to create and view application" do
    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    verification_result = Struct.new(:success?, :error, :message, keyword_init: true).new(success?: true)
    verifier_singleton = RepositoryConnections::VerifyConnection.singleton_class
    original_call = verifier_singleton.instance_method(:call)

    verifier_singleton.send(:define_method, :call) { |**| verification_result }

    begin
      post project_applications_url(projects(:one)), params: {
        application: {
          name: "Ledger API",
          description: "Ledger and accounting",
          runtime_key: "ruby-4",
          repository_url: "https://gitlab.example.com/tenant/ledger-api.git",
          repository_connection_id: repository_connections(:project_one_gitlab).id
        }
      }
    ensure
      verifier_singleton.send(:define_method, :call, original_call)
    end

    created = Application.find_by!(name: "Ledger API")
    assert_redirected_to project_application_url(projects(:one), created)

    get project_application_url(projects(:one), created)
    assert_response :success
    assert_includes response.body, "Ledger API"
    assert_includes response.body, "Ruby 4"
  end

  test "shows runtime options on new form" do
    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    get new_project_application_url(projects(:one))

    assert_response :success
    assert_includes response.body, "Ruby 4"
    assert_includes response.body, "Rails 8"
    assert_includes response.body, "Go 1.22"
    assert_includes response.body, "Repository URL"
    assert_includes response.body, repository_connections(:global_gitlab).name
    assert_includes response.body, repository_connections(:project_one_gitlab).name
  end

  test "returns forbidden for non-member access" do
    app = Application.create!(
      project: projects(:one),
      name: "Restricted App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/restricted-app.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    post session_url, params: {
      session: {
        username: users(:two).username,
        password: "password123"
      }
    }

    get project_application_url(projects(:one), app)
    assert_response :forbidden
  end

  test "reviewer cannot create application" do
    post session_url, params: {
      session: {
        username: users(:three).username,
        password: "password123"
      }
    }

    post project_applications_url(projects(:one)), params: {
      application: {
        name: "Reviewer Create App",
        description: "Should not be allowed",
        runtime_key: "ruby-4",
        repository_url: "https://gitlab.example.com/tenant/reviewer-create.git",
        repository_connection_id: repository_connections(:project_one_gitlab).id
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "Forbidden"
  end

  test "member can start a build for an application" do
    app = Application.create!(
      project: projects(:one),
      name: "Build Trigger App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/build-trigger.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    assert_difference("Build.count", 1) do
      post start_build_project_application_url(projects(:one), app), params: {
        source_ref: "main",
        commit_sha: "abc1234"
      }
    end

    assert_redirected_to project_application_url(projects(:one), app)
  end

  test "owner can update application webhook settings" do
    app = Application.create!(
      project: projects(:one),
      name: "Webhook Controller Settings App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://github.com/acme/controller-settings",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    patch update_webhook_project_application_url(projects(:one), app), params: {
      application: {
        webhook_enabled: true,
        webhook_event_policy: "merge_and_push",
        webhook_branch_filter: "main"
      }
    }

    assert_redirected_to project_application_url(projects(:one), app)
    app.reload
    assert_equal true, app.webhook_enabled
    assert_equal "merge_and_push", app.webhook_event_policy
    assert_equal "main", app.webhook_branch_filter
  end

  test "reviewer cannot update application webhook settings" do
    app = Application.create!(
      project: projects(:one),
      name: "Webhook Controller Settings Forbidden App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://github.com/acme/controller-settings-forbidden",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    post session_url, params: {
      session: {
        username: users(:three).username,
        password: "password123"
      }
    }

    patch update_webhook_project_application_url(projects(:one), app), params: {
      application: {
        webhook_enabled: true,
        webhook_event_policy: "merge_only",
        webhook_branch_filter: "main"
      }
    }

    assert_response :forbidden
  end

  test "application page defaults to overview tab with latest build label" do
    app = Application.create!(
      project: projects(:one),
      name: "Build Status App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/build-status.git",
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

    RepositoryWebhookEvent.create!(
      repository_connection: app.repository_connection,
      provider: "gitlab",
      delivery_id: "evt-controller-events-1",
      event_type: "merge",
      repository_url: app.repository_url,
      source_ref: "main",
      commit_sha: "a" * 40,
      status: "processed",
      payload_digest: "f" * 64,
      processed_at: Time.current
    )

    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    get project_application_url(projects(:one), app)

    assert_response :success
    assert_includes response.body, "Overview"
    assert_includes response.body, "Repository"
    assert_includes response.body, "Build History"
    assert_includes response.body, "Application Events"
    assert_not_includes response.body, "Most recent build"
    assert_includes response.body, "inline-flex items-center gap-1.5"
    assert_includes response.body, "Environments"
    assert_not_includes response.body, "Build details"
  end

  test "application page renders build history tab" do
    app = Application.create!(
      project: projects(:one),
      name: "Build History Tab App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/build-history-tab.git",
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

    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    get project_application_url(projects(:one), app, tab: "build_history")

    assert_response :success
    assert_includes response.body, "Build history"
    assert_includes response.body, "Build details"
    assert_includes response.body, "data-controller=\"auto-refresh\""
    assert_includes response.body, "data-auto-refresh-enabled-value=\"true\""
    assert_includes response.body, "data-auto-refresh-target=\"label\""
    assert_includes response.body, "inline-flex items-center gap-1.5"
  end

  test "application page renders events tab" do
    app = Application.create!(
      project: projects(:one),
      name: "Events Tab App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/events-tab.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    RepositoryWebhookEvent.create!(
      repository_connection: app.repository_connection,
      provider: "gitlab",
      delivery_id: "evt-events-tab-1",
      event_type: "merge",
      repository_url: app.repository_url,
      source_ref: "main",
      commit_sha: "a" * 40,
      status: "processed",
      payload_digest: "f" * 64,
      processed_at: Time.current
    )

    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    get project_application_url(projects(:one), app, tab: "events")

    assert_response :success
    assert_includes response.body, "Application events"
    assert_includes response.body, "Webhook merge"
  end

  test "application page renders build artifacts tab with image rows" do
    app = Application.create!(
      project: projects(:one),
      name: "Artifacts Tab App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/artifacts-tab.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    finished_at = Time.zone.parse("2026-05-28 03:33:35")

    build = Build.create!(
      application: app,
      requested_by: users(:one),
      status: "succeeded",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "ebf6345f1a971f41a7fd23e92a722973d3de4642",
      artifact_reference: "nexus.serverlab.intra/apps/plato/rails-demo-app:sha-ebf6345f1a971f41a7fd23e92a722973d3de4642",
      finished_at: finished_at
    )

    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    get project_application_url(projects(:one), app, tab: "build_artifacts")

    assert_response :success
    assert_includes response.body, "Build artifacts"
    assert_includes response.body, "Repository URL"
    assert_includes response.body, "Tag / Hash"
    assert_includes response.body, "nexus.serverlab.intra/apps/plato"
    assert_includes response.body, "rails-demo-app"
    assert_includes response.body, "sha-ebf6345f1a971f41a7fd23e92a722973d3de4642"
    assert_includes response.body, "ebf6345f1a971f41a7fd23e92a722973d3de4642"
    assert_includes response.body, "2026-05-28 03:33:35"
    assert_includes response.body, project_application_build_path(projects(:one), app, build)
  end

  test "member can view application event details" do
    app = Application.create!(
      project: projects(:one),
      name: "Event Detail App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/event-detail.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    webhook_event = RepositoryWebhookEvent.create!(
      repository_connection: app.repository_connection,
      provider: "gitlab",
      delivery_id: "evt-event-detail-1",
      event_type: "merge",
      repository_url: app.repository_url,
      source_ref: "main",
      commit_sha: "a" * 40,
      status: "processed",
      payload_digest: "e" * 64,
      processed_at: Time.current
    )

    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    get event_project_application_url(projects(:one), app, event_key: "webhook:#{webhook_event.id}")

    assert_response :success
    assert_includes response.body, "Event details"
    assert_includes response.body, "Webhook merge"
    assert_includes response.body, "gitlab webhook"
  end

  test "non-member cannot start build" do
    app = Application.create!(
      project: projects(:one),
      name: "Build Forbidden App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/build-forbidden.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    post session_url, params: {
      session: {
        username: users(:two).username,
        password: "password123"
      }
    }

    post start_build_project_application_url(projects(:one), app), params: {
      source_ref: "main",
      commit_sha: "abc1234"
    }

    assert_response :forbidden
  end

  test "member can discover repositories for a selected repository connection" do
    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    discoverer_singleton = RepositoryConnections::DiscoverRepositories.singleton_class
    original_call = discoverer_singleton.instance_method(:call)

    discoverer_singleton.send(:define_method, :call) do |**_kwargs|
      RepositoryConnections::DiscoverRepositories::Result.new(
        success?: true,
        repositories: [
          { name: "tenant/ledger-api", url: "https://gitlab.example.com/tenant/ledger-api.git" },
          { name: "tenant/payments-api", url: "https://gitlab.example.com/tenant/payments-api.git" }
        ]
      )
    end

    begin
      get discover_repositories_project_applications_url(projects(:one)), params: {
        repository_connection_id: repository_connections(:project_one_gitlab).id
      }
    ensure
      discoverer_singleton.send(:define_method, :call, original_call)
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body["success"]
    assert_equal 2, body["repositories"].size
    assert_equal "tenant/ledger-api", body["repositories"][0]["name"]
  end

  test "non-member cannot discover repositories" do
    post session_url, params: {
      session: {
        username: users(:two).username,
        password: "password123"
      }
    }

    get discover_repositories_project_applications_url(projects(:one)), params: {
      repository_connection_id: repository_connections(:project_one_gitlab).id
    }

    assert_response :forbidden
  end

  test "member can verify repository access from selected repository" do
    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    verifier_singleton = Applications::VerifyRepositoryAccess.singleton_class
    original_call = verifier_singleton.instance_method(:call)

    verifier_singleton.send(:define_method, :call) do |**_kwargs|
      Applications::VerifyRepositoryAccess::Result.new(success?: true, status: :verified, message: "Repository verified")
    end

    begin
      post verify_repository_access_project_applications_url(projects(:one)), params: {
        repository_connection_id: repository_connections(:project_one_gitlab).id,
        repository_input_mode: "select",
        selected_repository_url: "https://gitlab.example.com/tenant/ledger-api.git"
      }
    ensure
      verifier_singleton.send(:define_method, :call, original_call)
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body["success"]
    assert_equal "verified", body["status"]
  end

  test "owner can update build template to buildpacks" do
    app = Application.create!(
      project: projects(:one),
      name: "Build Template App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/build-template.git",
      repository_connection: repository_connections(:project_one_gitlab),
      build_template: "buildkit"
    )

    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    patch update_build_template_project_application_url(projects(:one), app), params: {
      build_template: "buildpacks"
    }

    assert_redirected_to project_application_url(projects(:one), app, tab: "repository")
    assert_equal "buildpacks", app.reload.build_template
  end

  test "reviewer cannot update build template" do
    app = Application.create!(
      project: projects(:one),
      name: "Build Template Forbidden App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/build-template-forbidden.git",
      repository_connection: repository_connections(:project_one_gitlab),
      build_template: "buildkit"
    )

    post session_url, params: {
      session: {
        username: users(:three).username,
        password: "password123"
      }
    }

    patch update_build_template_project_application_url(projects(:one), app), params: {
      build_template: "buildpacks"
    }

    assert_response :forbidden
    assert_equal "buildkit", app.reload.build_template
  end

  test "invalid build template returns unprocessable entity" do
    app = Application.create!(
      project: projects(:one),
      name: "Build Template Invalid App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/build-template-invalid.git",
      repository_connection: repository_connections(:project_one_gitlab),
      build_template: "buildkit"
    )

    post session_url, params: {
      session: {
        username: users(:one).username,
        password: "password123"
      }
    }

    patch update_build_template_project_application_url(projects(:one), app), params: {
      build_template: "bad_value"
    }

    assert_response :unprocessable_entity
    assert_equal "buildkit", app.reload.build_template
  end

  test "unauthenticated user cannot update build template" do
    app = Application.create!(
      project: projects(:one),
      name: "Build Template Unauth App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/tenant/build-template-unauth.git",
      repository_connection: repository_connections(:project_one_gitlab)
    )

    patch update_build_template_project_application_url(projects(:one), app), params: {
      build_template: "buildpacks"
    }

    assert_redirected_to new_session_url
  end
end
