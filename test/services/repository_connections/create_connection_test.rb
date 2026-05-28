require "test_helper"

class RepositoryConnectionsCreateConnectionTest < ActiveSupport::TestCase
  test "admin creates a global repository connection" do
    assert_difference("RepositoryConnection.count", 1) do
      assert_difference("AuditEvent.count", 1) do
        result = RepositoryConnections::CreateConnection.call(
          actor: users(:admin),
          scope: "global",
          params: {
            name: "Shared Billing Repo",
            provider: "gitlab",
            endpoint_url: "https://gitlab.example.com",
            auth_username: "oauth2",
            auth_secret: "super-secret-token"
          }
        )

        assert result.success?
        assert_equal "pending", result.repository_connection.validation_status
        assert_not_equal "super-secret-token", result.repository_connection.auth_secret_ciphertext
      end
    end
  end

  test "project owner creates a project repository connection" do
    assert_difference("RepositoryConnection.count", 1) do
      result = RepositoryConnections::CreateConnection.call(
        actor: users(:one),
        scope: "project",
        project: projects(:one),
        params: {
          name: "Project Billing Repo",
          provider: "gitlab",
          endpoint_url: "https://gitlab.example.com",
          auth_username: "oauth2",
          auth_secret: "super-secret-token",
          webhook_secret: "webhook-secret"
        }
      )

      assert result.success?
      assert_equal projects(:one), result.repository_connection.project
      assert_equal "webhook-secret", result.repository_connection.webhook_secret
    end
  end

  test "non-owner cannot create project repository connection" do
    result = RepositoryConnections::CreateConnection.call(
      actor: users(:two),
      scope: "project",
      project: projects(:one),
      params: {
        name: "Forbidden Repo",
        provider: "gitlab",
        endpoint_url: "https://gitlab.example.com",
        auth_username: "oauth2",
        auth_secret: "secret"
      }
    )

    assert_not result.success?
    assert_equal :forbidden, result.error
  end

  test "returns validation failure for invalid endpoint url" do
    result = RepositoryConnections::CreateConnection.call(
      actor: users(:admin),
      scope: "global",
      params: {
        name: "Broken Repo",
        provider: "gitlab",
        endpoint_url: "not-a-url",
        auth_username: "oauth2",
        auth_secret: "secret"
      }
    )

    assert_not result.success?
    assert_equal :validation_failed, result.error
    assert_equal 0, AuditEvent.where(action: "repository_connection.created").count
  end
end