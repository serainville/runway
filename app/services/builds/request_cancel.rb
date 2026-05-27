module Builds
  class RequestCancel
    Result = Struct.new(:success?, :build, :error, :message, keyword_init: true)

    def self.call(actor:, project:, application:, build:)
      new(actor: actor, project: project, application: application, build: build).call
    end

    def initialize(actor:, project:, application:, build:)
      @actor = actor
      @project = project
      @application = application
      @build = build
    end

    def call
      return Result.new(success?: false, error: :forbidden, message: "Forbidden") unless authorized?
      return Result.new(success?: false, error: :not_found, message: "Build not found") unless build.application_id == application.id
      return Result.new(success?: false, error: :not_cancelable, message: "Build is already complete") if build.terminal?

      Build.transaction do
        build.lock!
        return Result.new(success?: false, error: :not_cancelable, message: "Build is already complete") if build.terminal?

        build.cancel_requested = true
        transition = Builds::TransitionStatus.call(build: build, to_status: "canceled")
        return Result.new(success?: false, error: transition.error, message: transition.message) unless transition.success?

        build.save! if build.changed?

        AuditEvents::Record.call(
          actor: actor,
          action: "build.canceled",
          auditable: build,
          metadata: { cancellation_source: "user_request" }
        )
      end

      Result.new(success?: true, build: build)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error: :validation_failed, message: e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :actor, :project, :application, :build

    def authorized?
      actor.projects.exists?(id: project.id)
    end
  end
end
