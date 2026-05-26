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
end
