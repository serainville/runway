require "test_helper"

class DeploymentTargetTest < ActiveSupport::TestCase
  test "requires unique name" do
    duplicate = DeploymentTarget.new(name: deployment_targets(:one).name)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "kubernetes target requires credential reference" do
    target = DeploymentTarget.new(
      name: "k8s-without-credential",
      backend_type: "kubernetes",
      endpoint: "https://k8s.example.com",
      credential_reference: ""
    )

    assert_not target.valid?
    assert_includes target.errors[:credential_reference], "can't be blank"
  end

  test "kubernetes target requires ca bundle reference" do
    target = DeploymentTarget.new(
      name: "k8s-without-ca",
      backend_type: "kubernetes",
      endpoint: "https://k8s.example.com",
      credential_reference: "vault://backends/k8s-a/token",
      ca_bundle_reference: ""
    )

    assert_not target.valid?
    assert_includes target.errors[:ca_bundle_reference], "can't be blank"
  end

  test "kubernetes target requires https endpoint" do
    target = DeploymentTarget.new(
      name: "k8s-insecure-endpoint",
      backend_type: "kubernetes",
      endpoint: "http://k8s.example.com",
      credential_reference: "vault://backends/k8s-a/token"
    )

    assert_not target.valid?
    assert_includes target.errors[:endpoint], "must use https for kubernetes backends"
  end

  test "kubernetes target allows raw token and ca bundle values" do
    target = DeploymentTarget.new(
      name: "k8s-raw-secret-values",
      backend_type: "kubernetes",
      endpoint: "https://k8s.example.com",
      credential_reference: "raw-token-value",
      ca_bundle_reference: "-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----"
    )

    assert target.valid?
  end
end
