module Projects
  class AuthorizeAccess
    ACTIONS = %i[read manage_settings manage_members initiate_build initiate_deploy].freeze

    def self.call(actor:, project:, action:)
      new(actor: actor, project: project, action: action).call
    end

    def initialize(actor:, project:, action:)
      @actor = actor
      @project = project
      @action = action.to_sym
    end

    def call
      return false unless actor && project
      return false unless ACTIONS.include?(action)

      role = project.role_for(actor)

      case action
      when :read
        project.public? || role.present?
      when :manage_settings, :manage_members
        role == "owner"
      when :initiate_build, :initiate_deploy
        role == "owner" || role == "contributor"
      else
        false
      end
    end

    private

    attr_reader :actor, :project, :action
  end
end
