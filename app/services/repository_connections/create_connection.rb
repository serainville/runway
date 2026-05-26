module RepositoryConnections
  class CreateConnection
    Result = Struct.new(:success?, :repository_connection, :error, :message, keyword_init: true)

    def self.call(actor:, scope:, params:, project: nil)
      new(actor: actor, scope: scope, params: params, project: project).call
    end

    def initialize(actor:, scope:, params:, project:)
      @actor = actor
      @scope = scope
      @params = params
      @project = project
    end

    def call
      return forbidden unless authorized?

      repository_connection = RepositoryConnection.new(
        name: params[:name],
        scope: scope,
        project: scoped_project,
        provider: params[:provider],
        endpoint_url: params[:endpoint_url],
        auth_username: params[:auth_username],
        ca_bundle: params[:ca_bundle].to_s,
        auth_secret_ciphertext: RepositoryConnections::CredentialCipher.encrypt(params[:auth_secret]),
        validation_status: "pending"
      )

      if repository_connection.save
        AuditEvents::Record.call(
          actor: actor,
          action: "repository_connection.created",
          auditable: repository_connection,
          metadata: {
            scope: repository_connection.scope,
            project_id: repository_connection.project_id,
            provider: repository_connection.provider,
            endpoint_url: repository_connection.endpoint_url
          }
        )
        Result.new(success?: true, repository_connection: repository_connection)
      else
        Result.new(success?: false, error: :validation_failed, message: repository_connection.errors.full_messages.to_sentence)
      end
    end

    private

    attr_reader :actor, :scope, :params, :project

    def authorized?
      return actor&.admin? if scope == "global"

      ProjectMembership.exists?(project_id: project&.id, user_id: actor&.id, role: "owner")
    end

    def scoped_project
      scope == "project" ? project : nil
    end

    def forbidden
      Result.new(success?: false, error: :forbidden, message: "Not authorized")
    end
  end
end
