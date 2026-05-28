module Internal
  module Builds
    class WorkersController < ApplicationController
      before_action :require_worker_token!

      def claim
        result = ::Builds::ClaimNextBuild.call(
          worker_id: params[:worker_id],
          capabilities: params[:capabilities] || {}
        )

        if result.assigned
          build = result.build
          render json: {
            assigned: true,
            build_id: build.id,
            lease_id: build.lease_id,
            lease_ttl_seconds: lease_ttl_seconds,
            application_id: build.application_id,
            project_id: build.application.project_id,
            runtime_key: build.runtime_key,
            source: {
              repository_url: build.application.repository_url,
              ref: build.source_ref,
              commit_sha: build.commit_sha
            }
          }
        else
          render json: { assigned: false, poll_after_seconds: 5 }
        end
      end

      def heartbeat
        result = ::Builds::HeartbeatLease.call(
          build_id: params[:build_id],
          lease_id: params[:lease_id],
          worker_id: params[:worker_id],
          lease_ttl_seconds: lease_ttl_seconds
        )

        if result.success?
          render json: { ok: true, lease_ttl_seconds: lease_ttl_seconds, cancel_requested: result.build.cancel_requested }
        elsif result.error == :conflict
          render json: { ok: false, error: result.message }, status: :conflict
        else
          render json: { ok: false, error: result.message }, status: :unprocessable_entity
        end
      end

      def phase
        result = ::Builds::RecordPhase.call(
          build_id: params[:build_id],
          lease_id: params[:lease_id],
          phase: params[:phase],
          status: params[:status],
          message: params[:message],
          failure_code: params[:failure_code],
          reported_at: params[:timestamp].presence || Time.current
        )

        if result.success?
          render json: { ok: true }
        elsif result.error == :conflict
          render json: { ok: false, error: result.message }, status: :conflict
        else
          render json: { ok: false, error: result.message }, status: :unprocessable_entity
        end
      end

      def logs
        result = ::Builds::AppendLogChunk.call(
          build_id: params[:build_id],
          lease_id: params[:lease_id],
          phase: params[:phase],
          sequence: params[:sequence],
          chunk: params[:chunk],
          reported_at: params[:timestamp].presence || Time.current
        )

        if result.success?
          render json: { ok: true }
        elsif result.error == :conflict
          render json: { ok: false, error: result.message }, status: :conflict
        else
          render json: { ok: false, error: result.message }, status: :unprocessable_entity
        end
      end

      def complete
        result = ::Builds::Complete.call(
          build_id: params[:build_id],
          lease_id: params[:lease_id],
          status: params[:status],
          artifact_reference: params[:artifact_reference],
          failure_code: params[:failure_code],
          message: params[:message],
          finished_at: params[:finished_at].presence || Time.current
        )

        if result.success?
          render json: { ok: true }
        elsif result.error == :conflict
          render json: { ok: false, error: result.message }, status: :conflict
        else
          render json: { ok: false, error: result.message }, status: :unprocessable_entity
        end
      end

      private

      def require_worker_token!
        configured = ENV.fetch("RUNWAY_BUILD_WORKER_TOKEN", "")
        token = request.headers["X-Runway-Worker-Token"].to_s
        authorized = configured.present? && ActiveSupport::SecurityUtils.secure_compare(token, configured)
        return if authorized

        render json: { error: "Worker authentication required" }, status: :unauthorized
      end

      def lease_ttl_seconds
        30
      end
    end
  end
end
