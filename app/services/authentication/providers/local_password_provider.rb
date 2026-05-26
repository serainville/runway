module Authentication
  module Providers
    class LocalPasswordProvider < Base
      def authenticate(username:, password:)
        normalized_username = username.to_s.strip.downcase
        user = User.find_by(username: normalized_username)
        return invalid_credentials unless user&.authenticate(password)

        user.external_identities.find_or_create_by!(provider: "local", external_subject: user.email)

        Result.new(success?: true, user: user)
      end

      private

      def invalid_credentials
        Result.new(success?: false, error: :invalid_credentials, message: "Invalid username or password")
      end
    end
  end
end
