require "test_helper"

module Admin
  class BackendTargetsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated users" do
    get admin_backend_targets_url

    assert_redirected_to new_session_url
  end

  test "forbids non-admin users" do
    post session_url, params: { session: { username: users(:one).username, password: "password123" } }

    get admin_backend_targets_url

    assert_response :forbidden
  end

  test "admin can create and update kubernetes backend target" do
    post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

    assert_difference("DeploymentTarget.count", 1) do
      assert_difference("AuditEvent.count", 1) do
        post admin_backend_targets_url, params: {
          backend_target: {
            name: "Tenant Kubernetes A",
            description: "Primary non-production cluster",
            backend_type: "kubernetes",
            endpoint: "https://k8s-a.example.com",
            credential_reference: "raw-k8s-service-account-token",
            ca_bundle_reference: "-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----"
          }
        }
      end
    end

    target = DeploymentTarget.find_by!(name: "Tenant Kubernetes A")
    assert_redirected_to admin_backend_targets_url
    assert_equal "pending", target.validation_status

    assert_difference("AuditEvent.count", 1) do
      patch admin_backend_target_url(target), params: {
        backend_target: {
          backend_type: "kubernetes",
          endpoint: "https://k8s-b.example.com",
          credential_reference: "raw-k8s-service-account-token-b",
          ca_bundle_reference: "-----BEGIN CERTIFICATE-----\ndef\n-----END CERTIFICATE-----"
        }
      }
    end

    assert_redirected_to admin_backend_targets_url
    assert_equal "kubernetes", target.reload.backend_type
    assert_equal "https://k8s-b.example.com", target.reload.endpoint
  end

  test "admin can validate backend target connection" do
    post session_url, params: { session: { username: users(:admin).username, password: "password123" } }

    target = deployment_targets(:one)
    target.update!(
      backend_type: "kubernetes",
      endpoint: "https://k8s-a.example.com",
      credential_reference: "raw-k8s-service-account-token",
      ca_bundle_reference: "-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----",
      validation_status: "pending"
    )

    original_method = DeploymentTargets::ValidateTargetConnection.method(:call)
    DeploymentTargets::ValidateTargetConnection.define_singleton_method(:call) do |**_kwargs|
      DeploymentTargets::ValidateTargetConnection::Result.new(success?: true)
    end

    begin
      patch validate_connection_admin_backend_target_url(target)
    ensure
      DeploymentTargets::ValidateTargetConnection.define_singleton_method(:call, original_method)
    end

    assert_redirected_to admin_backend_targets_url
  end
end
end
