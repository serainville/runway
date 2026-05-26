class RepositoryConnection < ApplicationRecord
  PROVIDERS = %w[gitlab github bitbucket generic].freeze

  belongs_to :application

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :repo_url, presence: true
  validates :default_branch, presence: true
  validate :validate_repo_url

  private

  def validate_repo_url
    uri = URI.parse(repo_url)
    errors.add(:repo_url, "is invalid") unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    errors.add(:repo_url, "is invalid")
  end
end
