module Projects
  module Memberships
    class RemoveUser
      Result = Struct.new(:success?, :error, :message, keyword_init: true)

      def self.call(actor:, project_membership:)
        new(actor: actor, project_membership: project_membership).call
      end

      def initialize(actor:, project_membership:)
        @actor = actor
        @project_membership = project_membership
      end

      def call
        return forbidden unless authorized?

        removed_membership_snapshot = {
          user_id: project_membership.user_id,
          username: project_membership.user.username,
          role: project_membership.role
        }

        if removing_last_owner?
          return Result.new(success?: false, error: :validation_failed, message: "Project must keep at least one owner")
        end

        if project_membership.destroy
          AuditEvents::Record.call(
            actor: actor,
            action: "project_membership.removed",
            auditable: project_membership.project,
            metadata: {
              project_id: project_membership.project_id,
              user_id: project_membership.user_id,
              membership_before: removed_membership_snapshot,
              membership_after: nil
            }
          )
          Result.new(success?: true)
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

      attr_reader :actor, :project_membership

      def authorized?
        Projects::AuthorizeAccess.call(actor: actor, project: project_membership.project, action: :manage_members)
      end

      def removing_last_owner?
        project_membership.owner? && project_membership.project.project_memberships.where(role: "owner").count == 1
      end

      def forbidden
        Result.new(success?: false, error: :forbidden, message: "Not authorized")
      end
    end
  end
end
