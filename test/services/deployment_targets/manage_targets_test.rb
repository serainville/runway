require "test_helper"

class DeploymentTargetsManageTargetsTest < ActiveSupport::TestCase
  test "admin can create backend target" do
    assert_difference("DeploymentTarget.count", 1) do
      assert_difference("AuditEvent.count", 1) do
        result = DeploymentTargets::CreateTarget.call(
          actor: users(:admin),
          params: {
            name: "Docker Host A",
            description: "Primary docker host",
            backend_type: "docker",
            endpoint: "tcp://docker-a.example.com:2376",
            credential_reference: "vault://backends/docker-a"
          }
        )

        assert result.success?
      end
    end
  end

  test "create returns validation failure for missing endpoint" do
    result = DeploymentTargets::CreateTarget.call(
      actor: users(:admin),
      params: {
        name: "Invalid Target",
        backend_type: "kubernetes",
        endpoint: "",
        credential_reference: "vault://backends/k8s-a/token",
        ca_bundle_reference: "vault://backends/k8s-a/ca"
      }
    )

    assert_not result.success?
    assert_equal :validation_failed, result.error
  end

  test "non-admin cannot create backend target" do
    result = DeploymentTargets::CreateTarget.call(
      actor: users(:one),
      params: {
        name: "Forbidden Target",
        backend_type: "kubernetes",
        endpoint: "https://k8s.example.com"
      }
    )

    assert_not result.success?
    assert_equal :forbidden, result.error
  end
end
