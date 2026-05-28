require "test_helper"
require "openssl"

class WebhooksRepositoryEventsControllerTest < ActionDispatch::IntegrationTest
  test "accepts valid github webhook" do
    project = projects(:one)
    connection = RepositoryConnection.create!(
      name: "GitHub Hook",
      scope: "project",
      project: project,
      provider: "github",
      endpoint_url: "https://github.com",
      auth_username: "oauth2",
      auth_secret_ciphertext: RepositoryConnections::CredentialCipher.encrypt("token"),
      webhook_secret_ciphertext: RepositoryConnections::CredentialCipher.encrypt("webhook-secret"),
      validation_status: "validated"
    )

    application = Application.create!(
      project: project,
      name: "Webhook Controller App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://github.com/acme/controller-app",
      repository_connection: connection,
      webhook_enabled: true
    )

    payload = {
      action: "closed",
      pull_request: {
        merged: true,
        base: { ref: "main" },
        merge_commit_sha: "a" * 40
      },
      repository: {
        html_url: application.repository_url
      }
    }.to_json

    signature = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", "webhook-secret", payload)

    assert_difference("Build.count", 1) do
      post repository_webhook_path(provider: "github", repository_connection_id: connection.id),
        params: payload,
        headers: {
          "CONTENT_TYPE" => "application/json",
          "X-Hub-Signature-256" => signature,
          "X-GitHub-Delivery" => "delivery-controller-1"
        }
    end

    assert_response :accepted
  end

  test "returns not found for unknown repository connection" do
    post repository_webhook_path(provider: "github", repository_connection_id: 999_999),
      params: {}.to_json,
      headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :not_found
  end
end
