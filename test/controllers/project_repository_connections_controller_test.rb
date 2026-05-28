require "test_helper"

class ProjectRepositoryConnectionsControllerTest < ActionDispatch::IntegrationTest
  test "project owner can view repository connection details" do
    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    get project_repository_connection_url(projects(:one), repository_connections(:project_one_gitlab))

    assert_response :success
    assert_includes response.body, "Update Connection"
    assert_includes response.body, "Validation Troubleshooting"
    assert_includes response.body, "Back to connections"
  end

  test "project owner can create a project repository connection" do
    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    assert_difference("RepositoryConnection.count", 1) do
      post project_repository_connections_url(projects(:one)), params: {
        repository_connection: {
          name: "Project Web Repo",
          provider: "gitlab",
          endpoint_url: "https://gitlab.example.com",
          auth_username: "oauth2",
          auth_secret: "secret",
          ca_bundle: "-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----"
        }
      }
    end

    assert_redirected_to project_repository_connections_url(projects(:one))
    assert_equal "-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----", RepositoryConnection.order(:id).last.ca_bundle
  end

  test "non-owner cannot create a project repository connection" do
    post session_url, params: { session: { username: users(:two).username, password: "password123" } }

    post project_repository_connections_url(projects(:one)), params: {
      repository_connection: {
        name: "Forbidden Repo",
        provider: "gitlab",
        endpoint_url: "https://gitlab.example.com",
        auth_username: "oauth2",
        auth_secret: "secret"
      }
    }

    assert_response :forbidden
  end

  test "project owner can update a project repository connection" do
    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    connection = repository_connections(:project_one_gitlab)
    original_secret = connection.auth_secret_ciphertext

    assert_difference("AuditEvent.count", 1) do
      patch project_repository_connection_url(projects(:one), connection), params: {
        repository_connection: {
          name: "Tenant Ledger Source",
          provider: "gitlab",
          endpoint_url: "https://gitlab-tenant.example.com",
          auth_username: "tenant-bot",
          auth_secret: "",
          ca_bundle: "-----BEGIN CERTIFICATE-----\ntenant\n-----END CERTIFICATE-----"
        }
      }
    end

    assert_redirected_to project_repository_connection_url(projects(:one), connection)
    assert_equal "Tenant Ledger Source", connection.reload.name
    assert_equal "https://gitlab-tenant.example.com", connection.endpoint_url
    assert_equal "tenant-bot", connection.auth_username
    assert_equal "-----BEGIN CERTIFICATE-----\ntenant\n-----END CERTIFICATE-----", connection.ca_bundle
    assert_equal original_secret, connection.auth_secret_ciphertext
    assert_equal "pending", connection.validation_status
  end

  test "project owner can rotate project repository connection auth secret" do
    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    connection = repository_connections(:project_one_gitlab)
    original_secret_ciphertext = connection.auth_secret_ciphertext

    patch project_repository_connection_url(projects(:one), connection), params: {
      repository_connection: {
        name: connection.name,
        provider: connection.provider,
        endpoint_url: connection.endpoint_url,
        auth_username: connection.auth_username,
        auth_secret: "rotated-project-token",
        ca_bundle: connection.ca_bundle
      }
    }

    assert_redirected_to project_repository_connection_url(projects(:one), connection)
    assert_not_equal original_secret_ciphertext, connection.reload.auth_secret_ciphertext
    assert_equal "rotated-project-token", connection.auth_secret
  end

  test "project owner can rotate project repository webhook secret" do
    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    connection = repository_connections(:project_one_gitlab)
    original_webhook_ciphertext = connection.webhook_secret_ciphertext

    patch project_repository_connection_url(projects(:one), connection), params: {
      repository_connection: {
        name: connection.name,
        provider: connection.provider,
        endpoint_url: connection.endpoint_url,
        auth_username: connection.auth_username,
        auth_secret: "",
        webhook_secret: "rotated-webhook-secret",
        ca_bundle: connection.ca_bundle
      }
    }

    assert_redirected_to project_repository_connection_url(projects(:one), connection)
    assert_not_equal original_webhook_ciphertext, connection.reload.webhook_secret_ciphertext
    assert_equal "rotated-webhook-secret", connection.webhook_secret
  end

  test "non-owner cannot update a project repository connection" do
    post session_url, params: { session: { username: users(:two).username, password: "password123" } }

    patch project_repository_connection_url(projects(:one), repository_connections(:project_one_gitlab)), params: {
      repository_connection: {
        name: "Forbidden Update",
        provider: "gitlab",
        endpoint_url: "https://gitlab.example.com",
        auth_username: "oauth2",
        auth_secret: "secret"
      }
    }

    assert_response :forbidden
  end

  test "project owner can delete a project repository connection" do
    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    connection = repository_connections(:project_one_gitlab)

    assert_difference("RepositoryConnection.count", -1) do
      assert_difference("AuditEvent.count", 1) do
        delete project_repository_connection_url(projects(:one), connection)
      end
    end

    assert_redirected_to project_repository_connections_url(projects(:one))
  end

  test "non-owner cannot delete a project repository connection" do
    post session_url, params: { session: { username: users(:two).username, password: "password123" } }

    delete project_repository_connection_url(projects(:one), repository_connections(:project_one_gitlab))

    assert_response :forbidden
  end

  test "project owner can validate a project repository connection" do
    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    connection = repository_connections(:project_one_gitlab)
    original_method = RepositoryConnections::ValidateEndpointConnection.method(:call)
    RepositoryConnections::ValidateEndpointConnection.define_singleton_method(:call) do |**_kwargs|
      RepositoryConnections::ValidateEndpointConnection::Result.new(success?: true)
    end

    begin
      patch validate_connection_project_repository_connection_url(projects(:one), connection)
    ensure
      RepositoryConnections::ValidateEndpointConnection.define_singleton_method(:call, original_method)
    end

    assert_redirected_to project_repository_connection_url(projects(:one), connection)
  end

  test "non-owner cannot validate a project repository connection" do
    post session_url, params: { session: { username: users(:two).username, password: "password123" } }

    patch validate_connection_project_repository_connection_url(projects(:one), repository_connections(:project_one_gitlab))

    assert_response :forbidden
  end
end