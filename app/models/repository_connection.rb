class RepositoryConnection < ApplicationRecord
  PROVIDERS = %w[gitlab github bitbucket generic].freeze
  SCOPES = %w[global project].freeze
  VALIDATION_STATUSES = %w[pending validated validation_failed].freeze

  belongs_to :project, optional: true
  has_many :applications, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: [:scope, :project_id], case_sensitive: false }
  validates :scope, presence: true, inclusion: { in: SCOPES }
  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :endpoint_url, presence: true
  validates :auth_username, presence: true
  validates :auth_secret_ciphertext, presence: true
  validates :validation_status, presence: true, inclusion: { in: VALIDATION_STATUSES }
  validate :validate_endpoint_url
  validate :scope_project_consistency

  scope :validated, -> { where(validation_status: "validated") }
  scope :global_scope, -> { where(scope: "global") }
  scope :project_scope, -> { where(scope: "project") }

  def global?
    scope == "global"
  end

  def project?
    scope == "project"
  end

  def selection_label
    prefix = global? ? "Global" : "Project"
    "#{prefix}: #{name}"
  end

  def auth_secret
    RepositoryConnections::CredentialCipher.decrypt(auth_secret_ciphertext)
  end

  def webhook_secret
    RepositoryConnections::CredentialCipher.decrypt(webhook_secret_ciphertext)
  end

  private

  def validate_endpoint_url
    uri = URI.parse(endpoint_url)
    errors.add(:endpoint_url, "is invalid") unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    errors.add(:endpoint_url, "is invalid")
  end

  def scope_project_consistency
    if project?
      errors.add(:project, "must exist") unless project
    else
      errors.add(:project, "must be blank") if project
    end
  end
end
