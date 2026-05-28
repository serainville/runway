module RepositoryConnections
  class ValidateEndpointConnection
    Result = Struct.new(:success?, :error, :message, keyword_init: true)

    def self.call(actor:, repository_connection:, endpoint_validator: RepositoryConnections::ValidateEndpointAccess)
      new(
        actor: actor,
        repository_connection: repository_connection,
        endpoint_validator: endpoint_validator
      ).call
    end

    def initialize(actor:, repository_connection:, endpoint_validator:)
      @actor = actor
      @repository_connection = repository_connection
      @endpoint_validator = endpoint_validator
    end

    def call
      return forbidden unless authorized?

      validation_result = endpoint_validator.call(
        provider: repository_connection.provider,
        endpoint_url: repository_connection.endpoint_url,
        auth_username: repository_connection.auth_username,
        auth_secret: repository_connection.auth_secret,
        ca_bundle: repository_connection.ca_bundle
      )

      if validation_result.success?
        repository_connection.update!(validation_status: "validated")
        record_audit(status: "validated")
        Result.new(success?: true)
      else
        repository_connection.update!(validation_status: "validation_failed")
        record_audit(status: "validation_failed", error: validation_result.error)
        Result.new(success?: false, error: validation_result.error, message: validation_result.message)
      end
    rescue StandardError
      repository_connection.update!(validation_status: "validation_failed")
      record_audit(status: "validation_failed", error: :unexpected_error)
      Result.new(success?: false, error: :unexpected_error, message: "Repository connection validation failed unexpectedly")
    end

    private

    attr_reader :actor, :repository_connection, :endpoint_validator

    def record_audit(status:, error: nil)
      metadata = {
        scope: repository_connection.scope,
        project_id: repository_connection.project_id,
        provider: repository_connection.provider,
        endpoint_url: repository_connection.endpoint_url,
        validation_status: status
      }
      metadata[:error] = error if error

      AuditEvents::Record.call(
        actor: actor,
        action: "repository_connection.validated",
        auditable: repository_connection,
        metadata: metadata
      )
    end

    def forbidden
      Result.new(success?: false, error: :forbidden, message: "Not authorized")
    end

    def authorized?
      return actor&.admin? if repository_connection.global?
      return false unless repository_connection.project?

      Projects::AuthorizeAccess.call(actor: actor, project: repository_connection.project, action: :manage_settings)
    end
  end
end