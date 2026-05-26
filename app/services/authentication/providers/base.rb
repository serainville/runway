module Authentication
  module Providers
    class Base
      Result = Struct.new(:success?, :user, :error, :message, keyword_init: true)

      def authenticate(*)
        raise NotImplementedError, "Provider must implement authenticate"
      end
    end
  end
end
