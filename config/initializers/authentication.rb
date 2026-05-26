Rails.application.configure do
  config.x.authentication = ActiveSupport::OrderedOptions.new
  config.x.authentication.mode = ENV.fetch("RUNWAY_AUTH_MODE", "local")
end
