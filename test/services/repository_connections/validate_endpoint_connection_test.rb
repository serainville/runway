require "test_helper"

module RepositoryConnections
  class ValidateEndpointConnectionTest < ActiveSupport::TestCase
    class FakeEndpointValidatorSuccess
      def self.call(**)
        Struct.new(:success?, :error, :message, keyword_init: true).new(success?: true)
      end
    end

    class FakeEndpointValidatorFailure
      def self.call(**)
        Struct.new(:success?, :error, :message, keyword_init: true).new(
          success?: false,
          error: :auth_failed,
          message: "Runway could not authenticate to the repository endpoint"
        )
      end
    end

    class FakeEndpointValidatorError
      def self.call(**)
        raise OpenSSL::SSL::SSLError, "certificate verify failed"
      end
    end

    test "marks repository connection validated on successful endpoint validation" do
      connection = repository_connections(:global_gitlab)
      connection.update!(validation_status: "pending")

      result = RepositoryConnections::ValidateEndpointConnection.call(
        actor: users(:admin),
        repository_connection: connection,
        endpoint_validator: FakeEndpointValidatorSuccess
      )

      assert result.success?
      assert_equal "validated", connection.reload.validation_status
    end

    test "marks repository connection validation failed when endpoint validation fails" do
      connection = repository_connections(:global_gitlab)
      connection.update!(validation_status: "pending")

      result = RepositoryConnections::ValidateEndpointConnection.call(
        actor: users(:admin),
        repository_connection: connection,
        endpoint_validator: FakeEndpointValidatorFailure
      )

      assert_not result.success?
      assert_equal :auth_failed, result.error
      assert_equal "validation_failed", connection.reload.validation_status
    end

    test "returns failure instead of raising when endpoint validator raises" do
      connection = repository_connections(:global_gitlab)
      connection.update!(validation_status: "pending")

      result = RepositoryConnections::ValidateEndpointConnection.call(
        actor: users(:admin),
        repository_connection: connection,
        endpoint_validator: FakeEndpointValidatorError
      )

      assert_not result.success?
      assert_equal :unexpected_error, result.error
      assert_equal "validation_failed", connection.reload.validation_status
    end
  end
end