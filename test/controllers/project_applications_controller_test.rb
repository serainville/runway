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
    assert_includes response.body, "ruby 4"
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
end
