class RepositoryWebhookEvent < ApplicationRecord
  PROVIDERS = %w[gitlab github bitbucket].freeze
  STATUSES = %w[processed ignored_unsupported ignored_no_route failed].freeze

  belongs_to :repository_connection

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :delivery_id, presence: true, uniqueness: { scope: [:repository_connection_id, :provider], case_sensitive: false }
  validates :event_type, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :payload_digest, presence: true
end
