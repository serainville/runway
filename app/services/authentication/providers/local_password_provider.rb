module Authentication
  module Providers
    class LocalPasswordProvider < Base
      def authenticate(email:, password:)
        normalized_email = email.to_s.strip.downcase
        user = User.find_by(email: normalized_email)
        return invalid_credentials unless user&.authenticate(password)

        user.external_identities.find_or_create_by!(provider: "local", external_subject: user.email)

        Result.new(success?: true, user: user)
      end

      private

      def invalid_credentials
        Result.new(success?: false, error: :invalid_credentials, message: "Invalid email or password")
      end
    end
  end
end
