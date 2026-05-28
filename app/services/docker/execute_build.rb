require "json"
require "net/http"
require "securerandom"
require "cgi"

module Docker
  class ExecuteBuild
    Result = Struct.new(:success?, :error, :message, :container_id, :runtime_status, :request_events, keyword_init: true)

    def self.call(endpoint:, build:, http_runner: nil)
      new(endpoint: endpoint, build: build, http_runner: http_runner).call
    end

    def initialize(endpoint:, build:, http_runner: nil)
      @endpoint = endpoint
      @build = build
      @http_runner = http_runner
    end

    def call
      request_events = []

      pull_response = execute_request(
        method: :post,
        uri: URI.parse("#{docker_base_uri}/images/create?fromImage=#{CGI.escape(builder_image)}")
      )

      request_events << request_event(method: "POST", path: "/images/create", response: pull_response)
      unless pull_response.code.to_i.between?(200, 299)
        return Result.new(
          success?: false,
          error: :image_pull_failed,
          message: "Runway could not pull the builder image on the Docker host",
          request_events: request_events
        )
      end

      create_response = execute_request(
        method: :post,
        uri: URI.parse("#{docker_base_uri}/containers/create?name=#{container_name}"),
        body: container_payload
      )

      request_events << request_event(method: "POST", path: "/containers/create", response: create_response)

      return Result.new(success?: false, error: :container_create_failed, message: "Runway could not create a build container on the Docker host", request_events: request_events) unless create_response.code.to_i.between?(200, 299)

      container_id = JSON.parse(create_response.body).fetch("Id")

      start_response = execute_request(
        method: :post,
        uri: URI.parse("#{docker_base_uri}/containers/#{container_id}/start")
      )

      request_events << request_event(method: "POST", path: "/containers/#{container_id}/start", response: start_response)

      return Result.new(success?: false, error: :container_start_failed, message: "Runway could not start the build container on the Docker host", container_id: container_id, request_events: request_events) unless start_response.code.to_i.between?(200, 299)

      Result.new(success?: true, container_id: container_id, runtime_status: "running", request_events: request_events)
    rescue URI::InvalidURIError
      Result.new(success?: false, error: :invalid_endpoint, message: "Docker host endpoint is invalid")
    rescue StandardError
      Result.new(success?: false, error: :container_start_failed, message: "Runway could not start the build container on the Docker host")
    end

    private

    attr_reader :endpoint, :build, :http_runner

    def docker_base_uri
      if endpoint.start_with?("tcp://")
        endpoint.sub("tcp://", "http://")
      elsif endpoint.start_with?("http://") || endpoint.start_with?("https://")
        endpoint
      else
        raise URI::InvalidURIError, "invalid docker endpoint"
      end
    end

    def container_name
      "runway-build-#{build.id}-#{SecureRandom.hex(3)}"
    end

    def container_payload
      {
        Image: builder_image,
        Cmd: ["sh", "-lc", "echo runway-build-#{build.id}; sleep 1"],
        Labels: {
          "runway.build_id" => build.id.to_s,
          "runway.application_id" => build.application_id.to_s,
          "runway.source_ref" => build.source_ref,
          "runway.commit_sha" => build.commit_sha
        },
        HostConfig: {
          AutoRemove: true
        }
      }
    end

    def execute_request(method:, uri:, body: nil)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      if http_runner
        response = http_runner.call(method: method, uri: uri, body: body)
        elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
        response.define_singleton_method(:duration_ms) { elapsed_ms } unless response.respond_to?(:duration_ms)
        return response
      end

      request = case method
      when :post
        Net::HTTP::Post.new(uri)
      else
        raise ArgumentError, "unsupported method"
      end

      if body
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(body)
      end

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 10
      response = http.request(request)
      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      response.define_singleton_method(:duration_ms) { elapsed_ms }
      response
    end

    def request_event(method:, path:, response:)
      success = response.code.to_i.between?(200, 299)
      {
        request_method: method,
        request_path: path,
        response_status_code: response.code.to_i,
        duration_ms: response.respond_to?(:duration_ms) ? response.duration_ms : nil,
        success: success,
        error_code: success ? nil : "http_#{response.code.to_i}",
        error_message: success ? nil : parse_response_error_message(response.body)
      }
    end

    def parse_response_error_message(body)
      parsed = JSON.parse(body.to_s)
      parsed["message"].presence || parsed["error"].presence
    rescue JSON::ParserError
      message = body.to_s.strip
      message.present? ? message.truncate(300) : nil
    end

    def builder_image
      "alpine:3.20"
    end
  end
end