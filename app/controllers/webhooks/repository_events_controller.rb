module Webhooks
  class RepositoryEventsController < ApplicationController
    skip_forgery_protection

    def create
      repository_connection = RepositoryConnection.find_by(id: params[:repository_connection_id])
      return render json: { accepted: false, error: "repository_connection_not_found" }, status: :not_found unless repository_connection

      result = RepositoryWebhooks::ReceiveEvent.call(
        provider: params[:provider],
        repository_connection: repository_connection,
        headers: request.headers.to_h,
        raw_body: request.raw_post
      )

      if result.success?
        render json: { accepted: true, status: result.status.to_s }, status: :accepted
      elsif result.error == :unauthorized
        render json: { accepted: false, error: "signature_verification_failed" }, status: :unauthorized
      elsif result.error == :invalid_payload
        render json: { accepted: false, error: "invalid_payload" }, status: :bad_request
      elsif result.error == :invalid_provider
        render json: { accepted: false, error: "invalid_provider" }, status: :unprocessable_entity
      else
        render json: { accepted: false, error: result.error.to_s.presence || "processing_failed" }, status: :unprocessable_entity
      end
    rescue JSON::ParserError
      render json: { accepted: false, error: "invalid_payload" }, status: :bad_request
    end
  end
end
