module Applications
  class StartBuild
    Result = Struct.new(:success?, :build, :error, :message, keyword_init: true)

    def self.call(actor:, project:, application:, params: {}, queue_job: Builds::PumpQueueJob, head_commit_fetcher: RepositoryConnections::FetchHeadCommit)
      new(
        actor: actor,
        project: project,
        application: application,
        params: params,
        queue_job: queue_job,
        head_commit_fetcher: head_commit_fetcher
      ).call
    end

    def initialize(actor:, project:, application:, params: {}, queue_job:, head_commit_fetcher:)
      @actor = actor
      @project = project
      @application = application
      @params = params
      @queue_job = queue_job
      @head_commit_fetcher = head_commit_fetcher
    end

    def call
      return Result.new(success?: false, error: :forbidden, message: "Forbidden") unless authorized?
      return Result.new(success?: false, error: :validation_failed, message: "Application is not in this project") unless application.project_id == project.id
      commit_sha = resolve_commit_sha
      return Result.new(success?: false, error: :integration_failed, message: commit_sha[:message]) unless commit_sha[:success?]

      build = nil
      ActiveRecord::Base.transaction do
        if commit_sha[:commit_sha].match?(/\A[0-9a-f]{40}\z/i)
          application.update!(current_commit_sha: commit_sha[:commit_sha])
        end

        build = Build.create!(
          application: application,
          requested_by: actor,
          status: "pending",
          runtime_key: runtime_key,
          source_ref: source_ref,
          commit_sha: commit_sha[:commit_sha]
        )

        AuditEvents::Record.call(
          actor: actor,
          action: "build.requested",
          auditable: build,
          metadata: {
            application_id: application.id,
            project_id: project.id,
            source_ref: source_ref,
            commit_sha: commit_sha[:commit_sha]
          }
        )
      end

      queue_job.perform_later

      Result.new(success?: true, build: build)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error: :validation_failed, message: e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :actor, :project, :application, :params, :queue_job, :head_commit_fetcher

    def authorized?
      ProjectMembership.exists?(project_id: project.id, user_id: actor.id)
    end

    def runtime_key
      "#{application.runtime}-#{application.runtime_version}"
    end

    def source_ref
      params[:source_ref].presence || "main"
    end

    def commit_sha
      params[:commit_sha].presence || "manual"
    end

    def resolve_commit_sha
      requested_sha = commit_sha
      if requested_sha.present? && requested_sha != "manual"
        return { success?: true, commit_sha: requested_sha }
      end

      connection = application.repository_connection
      return { success?: false, message: "Application does not have a repository connection" } unless connection

      result = head_commit_fetcher.call(
        endpoint_url: connection.endpoint_url,
        repository_url: application.repository_url,
        auth_username: connection.auth_username,
        auth_secret: connection.auth_secret
      )

      return { success?: true, commit_sha: result.commit_sha } if result.success?
      return { success?: true, commit_sha: application.current_commit_sha } if application.current_commit_sha.present?

      { success?: false, message: result.message.presence || "Runway could not determine the current commit hash" }
    end
  end
end
