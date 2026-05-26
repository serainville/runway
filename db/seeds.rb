# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

DeploymentTargets::SeedDefault.call

default_admin_email = ENV.fetch("RUNWAY_DEFAULT_ADMIN_EMAIL", "admin@runway.local")
default_admin_username = ENV["RUNWAY_DEFAULT_ADMIN_USERNAME"].presence || "admin"
default_admin_password = ENV["RUNWAY_DEFAULT_ADMIN_PASSWORD"].presence || SecureRandom.base58(24)

default_admin_result = Authentication::BootstrapDefaultAdmin.call(
	email: default_admin_email,
	name: ENV.fetch("RUNWAY_DEFAULT_ADMIN_NAME", "Runway Admin"),
	username: default_admin_username,
	password: default_admin_password
)

if default_admin_result.success?
	puts "Runway default admin username: #{default_admin_result.user.username}"
	puts "Runway default admin password: #{default_admin_result.generated_password}"
else
	raise "Failed to bootstrap default admin: #{default_admin_result.message}"
end
