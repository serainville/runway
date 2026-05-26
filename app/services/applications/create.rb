module Applications
  class Create
    Result = Struct.new(:success?, :application, :error, :message, keyword_init: true)

    def self.call(actor:, team:, params:)
      new(actor: actor, team: team, params: params).call
    end

    def initialize(actor:, team:, params:)
      @actor = actor
      @team = team
      @params = params
    end

    def call
      return Result.new(success?: false, error: :not_found, message: "Team not found") unless team
      return Result.new(success?: false, error: :forbidden, message: "Forbidden") unless authorized?

      application = nil
      ActiveRecord::Base.transaction do
        application = Application.create!(team: team, **params)
        Environments::CreateDefault.call(application: application)
        AuditEvents::Record.call(
          actor: actor,
          team: team,
          action: "application.created",
          auditable: application,
          metadata: { application_name: application.name }
        )
      end

      Result.new(success?: true, application: application)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error: :validation_failed, message: e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :actor, :team, :params

    def authorized?
      Membership.exists?(user_id: actor.id, team_id: team.id)
    end
  end
end
