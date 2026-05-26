require "test_helper"

module RepositoryConnections
  class ValidateEndpointAccessTest < ActiveSupport::TestCase
    class FakeResponse
      attr_reader :code

      def initialize(code:, headers: {})
        @code = code
        @headers = headers
      end

      def [](key)
        @headers[key]
      end
    end

    test "returns auth_failed with http status context" do
      validator = RepositoryConnections::ValidateEndpointAccess.new(
        provider: "gitlab",
        endpoint_url: "https://gitlab.example.com",
        auth_username: "oauth2",
        auth_secret: "secret",
        ca_bundle: nil
      )
      validator.define_singleton_method(:perform_request) { |**| FakeResponse.new(code: "401") }

      result = validator.call

      assert_not result.success?
      assert_equal :auth_failed, result.error
      assert_equal "Repository endpoint rejected credentials (HTTP 401) while validating /api/v4/user", result.message
    end

    test "returns timeout reason when request times out" do
      validator = RepositoryConnections::ValidateEndpointAccess.new(
        provider: "gitlab",
        endpoint_url: "https://gitlab.example.com",
        auth_username: "oauth2",
        auth_secret: "secret",
        ca_bundle: nil
      )
      validator.define_singleton_method(:perform_request) { |**| raise Net::OpenTimeout, "execution expired" }

      result = validator.call

      assert_not result.success?
      assert_equal :timeout, result.error
      assert_equal "Repository endpoint request timed out: Net::OpenTimeout", result.message
    end

    test "returns server error details for 5xx responses" do
      validator = RepositoryConnections::ValidateEndpointAccess.new(
        provider: "gitlab",
        endpoint_url: "https://gitlab.example.com",
        auth_username: "oauth2",
        auth_secret: "secret",
        ca_bundle: nil
      )
      validator.define_singleton_method(:perform_request) { |**| FakeResponse.new(code: "503") }

      result = validator.call

      assert_not result.success?
      assert_equal :endpoint_server_error, result.error
      assert_equal "Repository endpoint returned a server error (HTTP 503) while validating /api/v4/user", result.message
    end

    test "returns redirect details for 302 responses" do
      validator = RepositoryConnections::ValidateEndpointAccess.new(
        provider: "gitlab",
        endpoint_url: "https://gitlab.example.com",
        auth_username: "oauth2",
        auth_secret: "secret",
        ca_bundle: nil
      )
      validator.define_singleton_method(:perform_request) do |**|
        FakeResponse.new(code: "302", headers: { "location" => "https://gitlab.example.com/users/sign_in" })
      end

      result = validator.call

      assert_not result.success?
      assert_equal :endpoint_redirected, result.error
      assert_equal "Repository endpoint redirected validation request (HTTP 302) to https://gitlab.example.com/users/sign_in while validating /api/v4/user. Verify endpoint URL/protocol and provider configuration", result.message
    end

    test "github provider falls back to gitlab api validation when github endpoints do not match" do
      validator = RepositoryConnections::ValidateEndpointAccess.new(
        provider: "github",
        endpoint_url: "https://gitlab.serverlab.intra",
        auth_username: "oauth2",
        auth_secret: "secret",
        ca_bundle: nil
      )

      validator.define_singleton_method(:perform_request) do |path:, auth_mode:|
        case [path, auth_mode]
        when ["/api/v3/user", :github_token]
          FakeResponse.new(code: "404")
        when ["/user", :github_token]
          FakeResponse.new(code: "302", headers: { "location" => "https://gitlab.serverlab.intra/users/sign_in" })
        when ["/api/v4/user", :gitlab_token]
          FakeResponse.new(code: "200")
        else
          FakeResponse.new(code: "500")
        end
      end

      result = validator.call

      assert result.success?
    end
  end
end