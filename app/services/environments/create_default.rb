module Environments
  class CreateDefault
    DEFAULT_ENVIRONMENT_NAME = "development".freeze

    def self.call(application:)
      application.environments.create!(name: DEFAULT_ENVIRONMENT_NAME, default: true)
    end
  end
end
