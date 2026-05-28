require "test_helper"
require "openssl"

class RepositoryWebhooksReceiveEventTest < ActiveSupport::TestCase
  class FakeBuildStarter
    cattr_accessor :calls, default: []

    Result = Struct.new(:success?, :build, :error, :message, keyword_init: true)

    def self.call(actor:, project:, application:, params:)
      self.calls += [ { actor: actor, project: project, application: application, params: params } ]
      Result.new(success?: true)
    end
  end

  setup do
    FakeBuildStarter.calls = []
  end

  test "github merged pull request triggers build for webhook-enabled application" do
    project = projects(:one)
    connection = RepositoryConnection.create!(
      name: "GitHub Project",
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
      name: "Webhook Build App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://github.com/acme/runway-app",
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

    assert_difference("RepositoryWebhookEvent.count", 1) do
      assert_difference("AuditEvent.count", 1) do
        result = RepositoryWebhooks::ReceiveEvent.call(
          provider: "github",
          repository_connection: connection,
          headers: {
            "X-Hub-Signature-256" => signature,
            "X-GitHub-Delivery" => "delivery-1"
          },
          raw_body: payload,
          build_starter: FakeBuildStarter
        )

        assert result.success?
        assert_equal :processed, result.status
      end
    end

    assert_equal 1, FakeBuildStarter.calls.length
    assert_equal application.id, FakeBuildStarter.calls.first[:application].id
  end

  test "duplicate delivery id is ignored" do
    project = projects(:one)
    connection = RepositoryConnection.create!(
      name: "GitHub Duplicate",
      scope: "project",
      project: project,
      provider: "github",
      endpoint_url: "https://github.com",
      auth_username: "oauth2",
      auth_secret_ciphertext: RepositoryConnections::CredentialCipher.encrypt("token"),
      webhook_secret_ciphertext: RepositoryConnections::CredentialCipher.encrypt("webhook-secret"),
      validation_status: "validated"
    )

    payload = {
      action: "closed",
      pull_request: {
        merged: true,
        base: { ref: "main" },
        merge_commit_sha: "a" * 40
      },
      repository: {
        html_url: "https://github.com/acme/runway-app"
      }
    }.to_json

    signature = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", "webhook-secret", payload)

    RepositoryWebhookEvent.create!(
      repository_connection: connection,
      provider: "github",
      delivery_id: "delivery-duplicate",
      event_type: "merge",
      status: "processed",
      payload_digest: "f" * 64
    )

    result = RepositoryWebhooks::ReceiveEvent.call(
      provider: "github",
      repository_connection: connection,
      headers: {
        "X-Hub-Signature-256" => signature,
        "X-GitHub-Delivery" => "delivery-duplicate"
      },
      raw_body: payload,
      build_starter: FakeBuildStarter
    )

    assert result.success?
    assert_equal :ignored_duplicate, result.status
    assert_empty FakeBuildStarter.calls
  end

  test "merge_only policy ignores push events" do
    project = projects(:one)
    connection = RepositoryConnection.create!(
      name: "GitHub Merge Only",
      scope: "project",
      project: project,
      provider: "github",
      endpoint_url: "https://github.com",
      auth_username: "oauth2",
      auth_secret_ciphertext: RepositoryConnections::CredentialCipher.encrypt("token"),
      webhook_secret_ciphertext: RepositoryConnections::CredentialCipher.encrypt("webhook-secret"),
      validation_status: "validated"
    )

    Application.create!(
      project: project,
      name: "Merge Only Policy App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://github.com/acme/merge-only-app",
      repository_connection: connection,
      webhook_enabled: true,
      webhook_event_policy: "merge_only"
    )

    payload = {
      ref: "refs/heads/main",
      after: "a" * 40,
      repository: {
        html_url: "https://github.com/acme/merge-only-app"
      }
    }.to_json

    signature = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", "webhook-secret", payload)

    result = RepositoryWebhooks::ReceiveEvent.call(
      provider: "github",
      repository_connection: connection,
      headers: {
        "X-Hub-Signature-256" => signature,
        "X-GitHub-Delivery" => "delivery-merge-only-push"
      },
      raw_body: payload,
      build_starter: FakeBuildStarter
    )

    assert result.success?
    assert_equal :ignored_no_route, result.status
    assert_empty FakeBuildStarter.calls
  end

  test "branch filter excludes non-matching branch" do
    project = projects(:one)
    connection = RepositoryConnection.create!(
      name: "GitHub Branch Filter",
      scope: "project",
      project: project,
      provider: "github",
      endpoint_url: "https://github.com",
      auth_username: "oauth2",
      auth_secret_ciphertext: RepositoryConnections::CredentialCipher.encrypt("token"),
      webhook_secret_ciphertext: RepositoryConnections::CredentialCipher.encrypt("webhook-secret"),
      validation_status: "validated"
    )

    Application.create!(
      project: project,
      name: "Branch Filter App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://github.com/acme/branch-filter-app",
      repository_connection: connection,
      webhook_enabled: true,
      webhook_event_policy: "merge_and_push",
      webhook_branch_filter: "release"
    )

    payload = {
      ref: "refs/heads/main",
      after: "a" * 40,
      repository: {
        html_url: "https://github.com/acme/branch-filter-app"
      }
    }.to_json

    signature = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", "webhook-secret", payload)

    result = RepositoryWebhooks::ReceiveEvent.call(
      provider: "github",
      repository_connection: connection,
      headers: {
        "X-Hub-Signature-256" => signature,
        "X-GitHub-Delivery" => "delivery-branch-filter-main"
      },
      raw_body: payload,
      build_starter: FakeBuildStarter
    )

    assert result.success?
    assert_equal :ignored_no_route, result.status
    assert_empty FakeBuildStarter.calls
  end

  test "invalid signature is rejected" do
    project = projects(:one)
    connection = RepositoryConnection.create!(
      name: "GitHub Invalid Signature",
      scope: "project",
      project: project,
      provider: "github",
      endpoint_url: "https://github.com",
      auth_username: "oauth2",
      auth_secret_ciphertext: RepositoryConnections::CredentialCipher.encrypt("token"),
      webhook_secret_ciphertext: RepositoryConnections::CredentialCipher.encrypt("webhook-secret"),
      validation_status: "validated"
    )

    payload = {
      action: "closed",
      pull_request: {
        merged: true,
        base: { ref: "main" },
        merge_commit_sha: "a" * 40
      },
      repository: {
        html_url: "https://github.com/acme/runway-app"
      }
    }.to_json

    result = RepositoryWebhooks::ReceiveEvent.call(
      provider: "github",
      repository_connection: connection,
      headers: {
        "X-Hub-Signature-256" => "sha256=invalid",
        "X-GitHub-Delivery" => "delivery-bad-sig"
      },
      raw_body: payload,
      build_starter: FakeBuildStarter
    )

    assert_not result.success?
    assert_equal :unauthorized, result.error
    assert_empty FakeBuildStarter.calls
  end
end
