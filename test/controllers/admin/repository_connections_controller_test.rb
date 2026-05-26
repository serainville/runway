require "test_helper"

module Admin
  class RepositoryConnectionsControllerTest < ActionDispatch::IntegrationTest
    test "admin can view repository connection details" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      get admin_repository_connection_url(repository_connections(:global_gitlab))

      assert_response :success
      assert_includes response.body, "Update Connection"
      assert_includes response.body, "Validation Troubleshooting"
    end

    test "admin can create a global repository connection" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      assert_difference("RepositoryConnection.count", 1) do
        post admin_repository_connections_url, params: {
          repository_connection: {
            name: "Shared Web Repo",
            provider: "gitlab",
            endpoint_url: "https://gitlab.example.com",
            auth_username: "oauth2",
            auth_secret: "secret",
            ca_bundle: "-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----"
          }
        }
      end

      assert_redirected_to admin_repository_connections_url
      assert_equal "-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----", RepositoryConnection.order(:id).last.ca_bundle
    end

    test "admin can update a global repository connection" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      connection = repository_connections(:global_gitlab)
      original_secret = connection.auth_secret_ciphertext

      assert_difference("AuditEvent.count", 1) do
        patch admin_repository_connection_url(connection), params: {
          repository_connection: {
            name: "Shared Payments GitLab",
            provider: "gitlab",
            endpoint_url: "https://gitlab-admin.example.com",
            auth_username: "platform-bot",
            auth_secret: "",
            ca_bundle: "-----BEGIN CERTIFICATE-----\nupdated\n-----END CERTIFICATE-----"
          }
        }
      end

      assert_redirected_to admin_repository_connection_url(connection)
      assert_equal "Shared Payments GitLab", connection.reload.name
      assert_equal "https://gitlab-admin.example.com", connection.endpoint_url
      assert_equal "platform-bot", connection.auth_username
      assert_equal "-----BEGIN CERTIFICATE-----\nupdated\n-----END CERTIFICATE-----", connection.ca_bundle
      assert_equal "pending", connection.validation_status
      assert_equal original_secret, connection.auth_secret_ciphertext
    end

    test "admin can rotate global repository connection auth secret" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      connection = repository_connections(:global_gitlab)
      original_secret_ciphertext = connection.auth_secret_ciphertext

      patch admin_repository_connection_url(connection), params: {
        repository_connection: {
          name: connection.name,
          provider: connection.provider,
          endpoint_url: connection.endpoint_url,
          auth_username: connection.auth_username,
          auth_secret: "rotated-global-token",
          ca_bundle: connection.ca_bundle
        }
      }

      assert_redirected_to admin_repository_connection_url(connection)
      assert_not_equal original_secret_ciphertext, connection.reload.auth_secret_ciphertext
      assert_equal "rotated-global-token", connection.auth_secret
    end

    test "admin can delete a global repository connection" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      connection = repository_connections(:global_gitlab)

      assert_difference("RepositoryConnection.count", -1) do
        assert_difference("AuditEvent.count", 1) do
          delete admin_repository_connection_url(connection)
        end
      end

      assert_redirected_to admin_repository_connections_url
    end

    test "admin can validate a global repository connection" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      connection = repository_connections(:global_gitlab)
      original_method = RepositoryConnections::ValidateEndpointConnection.method(:call)
      RepositoryConnections::ValidateEndpointConnection.define_singleton_method(:call) do |**_kwargs|
        RepositoryConnections::ValidateEndpointConnection::Result.new(success?: true)
      end

      begin
        patch validate_connection_admin_repository_connection_url(connection)
      ensure
        RepositoryConnections::ValidateEndpointConnection.define_singleton_method(:call, original_method)
      end

      assert_redirected_to admin_repository_connection_url(connection)
    end

    test "admin validate failure redirects with alert instead of raising" do
      post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

      connection = repository_connections(:global_gitlab)
      original_method = RepositoryConnections::ValidateEndpointConnection.method(:call)
      RepositoryConnections::ValidateEndpointConnection.define_singleton_method(:call) do |**_kwargs|
        RepositoryConnections::ValidateEndpointConnection::Result.new(
          success?: false,
          error: :tls_validation_failed,
          message: "TLS validation failed while contacting the repository endpoint"
        )
      end

      begin
        patch validate_connection_admin_repository_connection_url(connection)
      ensure
        RepositoryConnections::ValidateEndpointConnection.define_singleton_method(:call, original_method)
      end

      assert_redirected_to admin_repository_connection_url(connection)
      assert_equal "TLS validation failed while contacting the repository endpoint", flash[:alert]
    end
  end
end