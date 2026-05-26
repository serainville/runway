module Authentication
  module Providers
    class Resolver
      def self.call(mode)
        case mode.to_s
        when "local"
          LocalPasswordProvider.new
        else
          nil
        end
      end
    end
  end
end
