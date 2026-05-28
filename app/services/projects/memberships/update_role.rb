module Projects
  module Memberships
    class UpdateRole
      Result = Struct.new(:success?, :project_membership, :error, :message, keyword_init: true)

      def self.call(actor:, project_membership:, role:)
        new(actor: actor, project_membership: project_membership, role: role).call
      end

      def initialize(actor:, project_membership:, role:)
        @actor = actor
        @project_membership = project_membership
        @role = role.to_s
      end

      def call
        return forbidden unless authorized?

        previous_role = project_membership.role

        if removing_last_owner?
          return Result.new(success?: false, error: :validation_failed, message: "Project must keep at least one owner")
        end

        if project_membership.update(role: role)
          AuditEvents::Record.call(
            actor: actor,
            action: "project_membership.role_updated",
            auditable: project_membership.project,
            metadata: {
              project_id: project_membership.project_id,
              user_id: project_membership.user_id,
              membership_before: {
                user_id: project_membership.user_id,
                username: project_membership.user.username,
                role: previous_role
              },
              membership_after: {
                user_id: project_membership.user_id,
                username: project_membership.user.username,
                role: project_membership.role
              }
            }
          )
          Result.new(success?: true, project_membership: project_membership)
        else
          Result.new(success?: false, error: :validation_failed, message: project_membership.errors.full_messages.to_sentence)
        end
      rescue ActiveRecord::StatementInvalid => e
        if e.message.include?("project must keep at least one owner")
          Result.new(success?: false, error: :validation_failed, message: "Project must keep at least one owner")
        else
          raise
        end
      end

      private

      attr_reader :actor, :project_membership, :role

      def authorized?
        Projects::AuthorizeAccess.call(actor: actor, project: project_membership.project, action: :manage_members)
      end

      def removing_last_owner?
        project_membership.owner? && role != "owner" && project_membership.project.project_memberships.where(role: "owner").count == 1
      end

      def forbidden
        Result.new(success?: false, error: :forbidden, message: "Not authorized")
      end
    end
  end
end
