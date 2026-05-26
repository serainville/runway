require "test_helper"

class DeploymentTargetsValidateTargetConnectionTest < ActiveSupport::TestCase
  class FakeAccessValidatorSuccess
    def self.call(endpoint:, token:, ca_bundle:)
      Kubernetes::ValidateAccess::Result.new(success?: true)
    end
  end

  class FakeAccessValidatorMissingCa
    def self.call(endpoint:, token:, ca_bundle:)
      Kubernetes::ValidateAccess::Result.new(success?: false, error: :missing_ca_bundle, message: "Kubernetes CA bundle is missing")
    end
  end

  test "validates kubernetes backend and records audit event" do
    target = deployment_targets(:one)
    target.update!(
      backend_type: "kubernetes",
      endpoint: "https://k8s-a.example.com",
      credential_reference: "vault://backends/k8s-a/token",
      ca_bundle_reference: "vault://backends/k8s-a/ca",
      validation_status: "pending"
    )

    assert_difference("AuditEvent.count", 1) do
      result = DeploymentTargets::ValidateTargetConnection.call(
        actor: users(:admin),
        backend_target: target,
        access_validator: FakeAccessValidatorSuccess
      )

      assert result.success?
    end

    assert_equal "validated", target.reload.validation_status
  end

  test "sets validation_failed when access validator reports missing ca bundle" do
    target = deployment_targets(:one)
    target.update!(
      backend_type: "kubernetes",
      endpoint: "https://k8s-a.example.com",
      credential_reference: "raw-token",
      ca_bundle_reference: "not-a-valid-ca-bundle",
      validation_status: "pending"
    )

    assert_difference("AuditEvent.count", 1) do
      result = DeploymentTargets::ValidateTargetConnection.call(
        actor: users(:admin),
        backend_target: target,
        access_validator: FakeAccessValidatorMissingCa
      )

      assert_not result.success?
      assert_equal :missing_ca_bundle, result.error
    end

    assert_equal "validation_failed", target.reload.validation_status
  end

  test "forbids non-admin actors" do
    result = DeploymentTargets::ValidateTargetConnection.call(actor: users(:one), backend_target: deployment_targets(:one))

    assert_not result.success?
    assert_equal :forbidden, result.error
  end

end
