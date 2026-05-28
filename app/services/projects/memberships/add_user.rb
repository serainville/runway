module Projects
  module Memberships
    class AddUser
      Result = Struct.new(:success?, :project_membership, :error, :message, keyword_init: true)

      def self.call(actor:, project:, username:, role:)
        new(actor: actor, project: project, username: username, role: role).call
      end

      def initialize(actor:, project:, username:, role:)
        @actor = actor
        @project = project
        @username = username.to_s.strip.downcase
        @role = role.to_s
      end

      def call
        return forbidden unless authorized?

        user = User.find_by(username: username)
        return Result.new(success?: false, error: :validation_failed, message: "User not found") unless user

        membership = ProjectMembership.new(project: project, user: user, role: role)
        if membership.save
          AuditEvents::Record.call(
            actor: actor,
            action: "project_membership.added",
            auditable: project,
            metadata: {
              project_id: project.id,
              user_id: user.id,
              username: user.username,
              membership_before: nil,
              membership_after: {
                user_id: user.id,
                username: user.username,
                role: membership.role
              }
            }
          )
          Result.new(success?: true, project_membership: membership)
        else
          Result.new(success?: false, error: :validation_failed, message: membership.errors.full_messages.to_sentence)
        end
      end

      private

      attr_reader :actor, :project, :username, :role

      def authorized?
        Projects::AuthorizeAccess.call(actor: actor, project: project, action: :manage_members)
      end

      def forbidden
        Result.new(success?: false, error: :forbidden, message: "Not authorized")
      end
    end
  end
end
