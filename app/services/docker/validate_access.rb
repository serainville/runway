require "net/http"

module Docker
  class ValidateAccess
    Result = Struct.new(:success?, :error, :message, keyword_init: true)

    def self.call(endpoint:, http_getter: nil)
      new(endpoint: endpoint, http_getter: http_getter).call
    end

    def initialize(endpoint:, http_getter: nil)
      @endpoint = endpoint
      @http_getter = http_getter
    end

    def call
      uri = docker_uri
      response = http_getter ? http_getter.call(uri) : perform_http_get(uri)

      if response.code.to_i.between?(200, 299)
        Result.new(success?: true)
      else
        Result.new(success?: false, error: :unreachable, message: "Runway could not reach the Docker host")
      end
    rescue URI::InvalidURIError
      Result.new(success?: false, error: :invalid_endpoint, message: "Docker host endpoint is invalid")
    rescue StandardError
      Result.new(success?: false, error: :unreachable, message: "Runway could not reach the Docker host")
    end

    private

    attr_reader :endpoint, :http_getter

    def docker_uri
      if endpoint.start_with?("tcp://")
        URI.parse(endpoint.sub("tcp://", "http://") + "/_ping")
      elsif endpoint.start_with?("http://") || endpoint.start_with?("https://")
        URI.parse(endpoint + "/_ping")
      else
        raise URI::InvalidURIError, "invalid docker endpoint"
      end
    end

    def perform_http_get(uri)
      request = Net::HTTP::Get.new(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 5
      http.request(request)
    end
  end
end
