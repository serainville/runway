class ExternalIdentity < ApplicationRecord
  PROVIDERS = %w[local ldap oidc].freeze

  belongs_to :user

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :external_subject, presence: true, uniqueness: { scope: :provider, case_sensitive: false }
end
