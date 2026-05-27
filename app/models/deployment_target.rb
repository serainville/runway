class DeploymentTarget < ApplicationRecord
	BACKEND_TYPES = %w[kubernetes].freeze
	VALIDATION_STATUSES = %w[pending validated validation_failed].freeze

	has_many :environments, dependent: :restrict_with_error

	validates :name, presence: true, uniqueness: true
	validates :backend_type, presence: true, inclusion: { in: BACKEND_TYPES }
	validates :endpoint, presence: true
	validates :credential_reference, presence: true, if: :kubernetes?
	validates :ca_bundle_reference, presence: true, if: :kubernetes?
	validates :validation_status, presence: true, inclusion: { in: VALIDATION_STATUSES }

	validate :kubernetes_endpoint_must_use_https

	def kubernetes?
		backend_type == "kubernetes"
	end

	private

	def kubernetes_endpoint_must_use_https
		return unless kubernetes?
		return if endpoint.blank?

		uri = URI.parse(endpoint)
		return if uri.is_a?(URI::HTTPS)

		errors.add(:endpoint, "must use https for kubernetes backends")
	rescue URI::InvalidURIError
		errors.add(:endpoint, "must be a valid URL")
	end

end
