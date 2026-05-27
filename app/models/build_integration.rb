class BuildIntegration < ApplicationRecord
  INTEGRATION_TYPES = %w[docker_host executor_registration].freeze
  VALIDATION_STATUSES = %w[pending validated validation_failed].freeze
  EXECUTOR_HEARTBEAT_STATUSES = %w[online offline unknown].freeze

  scope :active_validated, -> { where(active: true, validation_status: "validated") }
  scope :default_active_validated, -> { active_validated.where(default: true) }

  validates :name, presence: true, uniqueness: true
  validates :integration_type, presence: true, inclusion: { in: INTEGRATION_TYPES }
  validates :endpoint, presence: true
  validates :validation_status, presence: true, inclusion: { in: VALIDATION_STATUSES }
  validates :default, inclusion: { in: [true, false] }

  validate :endpoint_must_use_supported_scheme
  validate :default_requires_active_and_validated

  private

  def endpoint_must_use_supported_scheme
    return unless integration_type.in?(INTEGRATION_TYPES)
    return if endpoint.blank?

    uri = URI.parse(endpoint)
    valid_schemes = integration_type == "docker_host" ? %w[tcp http https] : %w[http https]
    return if valid_schemes.include?(uri.scheme)

    errors.add(:endpoint, "must be a valid endpoint URL")
  rescue URI::InvalidURIError
    errors.add(:endpoint, "must be a valid endpoint URL")
  end

  def default_requires_active_and_validated
    return unless self.default
    errors.add(:default, "is only supported for docker host integrations") unless integration_type == "docker_host"
    errors.add(:default, "requires an active integration") unless active
    errors.add(:default, "requires validation") unless validation_status == "validated"
  end

  public

  def executor_registration?
    integration_type == "executor_registration"
  end

  def executor_heartbeat_status(now: Time.current, offline_after_seconds: self.class.executor_offline_after_seconds)
    return "unknown" unless executor_registration?
    return "unknown" if last_heartbeat_at.blank?

    if last_heartbeat_at >= now - offline_after_seconds.seconds
      "online"
    else
      "offline"
    end
  end

  def self.executor_offline_after_seconds
    Integer(ENV.fetch("RUNWAY_EXECUTOR_OFFLINE_AFTER_SECONDS", "90"), 10)
  rescue ArgumentError
    90
  end
end