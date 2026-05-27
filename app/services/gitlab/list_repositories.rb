require "net/http"
require "json"

module Gitlab
  class ListRepositories
    class Error < StandardError; end

    def self.call(endpoint_url:, auth_username:, auth_secret:, ca_bundle: nil)
      new(
        endpoint_url: endpoint_url,
        auth_username: auth_username,
        auth_secret: auth_secret,
        ca_bundle: ca_bundle
      ).call
    end

    def initialize(endpoint_url:, auth_username:, auth_secret:, ca_bundle: nil)
      @endpoint_url = endpoint_url
      @auth_username = auth_username
      @auth_secret = auth_secret
      @ca_bundle = ca_bundle
    end

    def call
      response = request_projects
      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "Runway could not list repositories from the selected connection"
      end

      payload = JSON.parse(response.body)
      payload.filter_map do |project|
        url = project["http_url_to_repo"].presence || project["web_url"].to_s
        next if url.blank?

        {
          name: project["path_with_namespace"].presence || project["name_with_namespace"].presence || project["name"].to_s,
          url: url
        }
      end
    rescue JSON::ParserError
      raise Error, "Runway received an invalid repository list response from the selected connection"
    rescue StandardError => e
      raise e if e.is_a?(Error)

      raise Error, "Runway could not list repositories from the selected connection"
    end

    private

    attr_reader :endpoint_url, :auth_username, :auth_secret, :ca_bundle

    def request_projects
      base_uri = URI.parse(endpoint_url)
      uri = URI.join(base_uri.to_s.end_with?("/") ? base_uri.to_s : "#{base_uri}/", "api/v4/projects?membership=true&simple=true&per_page=100")
      request = Net::HTTP::Get.new(uri)
      request["PRIVATE-TOKEN"] = auth_secret.to_s
      request.basic_auth(auth_username.to_s, auth_secret.to_s) if auth_username.present?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 10
      if http.use_ssl?
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        if ca_bundle.present?
          cert_store = OpenSSL::X509::Store.new
          cert_store.set_default_paths
          cert_store.add_cert(OpenSSL::X509::Certificate.new(ca_bundle))
          http.cert_store = cert_store
        end
      end

      http.request(request)
    end
  end
end
