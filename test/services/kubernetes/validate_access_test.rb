require "test_helper"

class KubernetesValidateAccessTest < ActiveSupport::TestCase
  test "returns invalid endpoint for non-https urls" do
    result = Kubernetes::ValidateAccess.call(endpoint: "http://example.com", token: "token", ca_bundle: "ca")

    assert_not result.success?
    assert_equal :invalid_endpoint, result.error
  end

  test "returns missing token when token is blank" do
    result = Kubernetes::ValidateAccess.call(endpoint: "https://example.com", token: " ", ca_bundle: "ca")

    assert_not result.success?
    assert_equal :missing_token, result.error
  end

  test "returns missing ca bundle when ca bundle is blank" do
    result = Kubernetes::ValidateAccess.call(endpoint: "https://example.com", token: "token", ca_bundle: " ")

    assert_not result.success?
    assert_equal :missing_ca_bundle, result.error
  end

  test "normalizes escaped newlines in ca bundle" do
    service = Kubernetes::ValidateAccess.new(
      endpoint: "https://example.com",
      token: "token",
      ca_bundle: "-----BEGIN CERTIFICATE-----\\nabc\\n-----END CERTIFICATE-----"
    )

    normalized = service.send(:ca_bundle)

    assert_includes normalized, "\nabc\n"
    assert_equal false, normalized.include?("\\n")
  end
end
