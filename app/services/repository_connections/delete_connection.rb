module RepositoryConnections
  class DeleteConnection
    Result = Struct.new(:success?, :error, :message, keyword_init: true)

    def self.call(actor:, repository_connection:)
      new(actor: actor, repository_connection: repository_connection).call
    end

    def initialize(actor:, repository_connection:)
      @actor = actor
      @repository_connection = repository_connection
    end

    def call
      return forbidden unless authorized?

      if repository_connection.destroy
        AuditEvents::Record.call(
          actor: actor,
          action: "repository_connection.deleted",
          auditable: repository_connection,
          metadata: {
            scope: repository_connection.scope,
            project_id: repository_connection.project_id,
            provider: repository_connection.provider,
            endpoint_url: repository_connection.endpoint_url
          }
        )
        Result.new(success?: true)
      else
        Result.new(success?: false, error: :validation_failed, message: repository_connection.errors.full_messages.to_sentence)
      end
    end

    private

    attr_reader :actor, :repository_connection

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