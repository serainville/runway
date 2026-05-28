module Builds
  class RecordHostRequestEvent
    Result = Struct.new(:success?, :event, :error, :message, keyword_init: true)

    def self.call(build:, params:)
      new(build: build, params: params).call
    end

    def initialize(build:, params:)
      @build = build
      @params = params
    end

    def call
      event = build.build_host_request_events.create!(params)
      Result.new(success?: true, event: event)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error: :validation_failed, message: e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :build, :params
  end
end