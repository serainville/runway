module RepositoryConnections
  class UpdateConnection
    Result = Struct.new(:success?, :repository_connection, :error, :message, keyword_init: true)

    def self.call(actor:, repository_connection:, params:)
      new(actor: actor, repository_connection: repository_connection, params: params).call
    end

    def initialize(actor:, repository_connection:, params:)
      @actor = actor
      @repository_connection = repository_connection
      @params = params
    end

    def call
      return forbidden unless authorized?

      if repository_connection.update(update_attributes)
        AuditEvents::Record.call(
          actor: actor,
          action: "repository_connection.updated",
          auditable: repository_connection,
          metadata: {
            scope: repository_connection.scope,
            project_id: repository_connection.project_id,
            provider: repository_connection.provider,
            endpoint_url: repository_connection.endpoint_url,
            validation_status: repository_connection.validation_status
          }
        )

        Result.new(success?: true, repository_connection: repository_connection)
      else
        Result.new(success?: false, error: :validation_failed, message: repository_connection.errors.full_messages.to_sentence)
      end
    end

    private

    attr_reader :actor, :repository_connection, :params

    def update_attributes
      attrs = {
        name: params[:name],
        provider: params[:provider],
        endpoint_url: params[:endpoint_url],
        auth_username: params[:auth_username],
        ca_bundle: params[:ca_bundle].to_s,
        validation_status: "pending"
      }
      attrs[:auth_secret_ciphertext] = RepositoryConnections::CredentialCipher.encrypt(params[:auth_secret]) if params[:auth_secret].present?
      attrs
    end

    def forbidden
      Result.new(success?: false, error: :forbidden, message: "Not authorized")
    end

    def authorized?
      return actor&.admin? if repository_connection.global?
      return false unless repository_connection.project?

      ProjectMembership.exists?(project_id: repository_connection.project_id, user_id: actor&.id, role: "owner")
    end
  end
end