module Projects
  class CreateProject
    Result = Struct.new(:success?, :project, :error, :message, keyword_init: true)

    def self.call(actor:, params:)
      new(actor: actor, params: params).call
    end

    def initialize(actor:, params:)
      @actor = actor
      @params = params
    end

    def call
      project = nil

      ActiveRecord::Base.transaction do
        project = Project.create!(params)
        ProjectMembership.create!(project: project, user: actor, role: "owner")
        AuditEvents::Record.call(
          actor: actor,
          action: "project.created",
          auditable: project,
          metadata: {
            project_name: project.name
          }
        )
      end

      Result.new(success?: true, project: project)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error: :validation_failed, message: e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :actor, :params
  end
end
