class Application < ApplicationRecord
  BUILD_TEMPLATES = %w[buildkit buildpacks].freeze
  WEBHOOK_EVENT_POLICIES = %w[merge_only merge_and_push].freeze

  belongs_to :team, optional: true
  belongs_to :project, optional: true
  belongs_to :repository_connection, optional: true
  belongs_to :runtime_option, optional: true
  has_many :environments, dependent: :destroy
  has_many :builds, dependent: :destroy
  has_many :audit_events, as: :auditable, dependent: :nullify

  validates :name, presence: true
  validates :slug, presence: true
  validates :webhook_enabled, inclusion: { in: [true, false] }
  validates :webhook_event_policy, inclusion: { in: WEBHOOK_EVENT_POLICIES }
  validates :webhook_branch_filter, length: { maximum: 255 }
  validates :build_template, presence: true, inclusion: { in: BUILD_TEMPLATES }
  validates :repository_url, presence: true, if: :project_owned?
  validates :runtime, presence: true, if: :project_owned?
  validates :runtime_version, presence: true, if: :project_owned?
  validates :current_commit_sha, format: { with: /\A[0-9a-f]{40}\z/i, message: "must be a 40-character SHA" }, allow_blank: true

  validates :name, uniqueness: { scope: :team_id, case_sensitive: false }, if: :team_owned?
  validates :slug, uniqueness: { scope: :team_id, case_sensitive: false }, if: :team_owned?
  validates :name, uniqueness: { scope: :project_id, case_sensitive: false }, if: :project_owned?
  validates :slug, uniqueness: { scope: :project_id, case_sensitive: false }, if: :project_owned?

  validate :ownership_boundary_present
  validate :validate_repository_url, if: :project_owned?

  before_validation :set_slug

  private

  def set_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end

  def team_owned?
    team_id.present?
  end

  def project_owned?
    project_id.present?
  end

  def ownership_boundary_present
    return if team_owned? || project_owned?

    errors.add(:base, "Application must belong to a project or team")
  end

  def validate_repository_url
    uri = URI.parse(repository_url)
    errors.add(:repository_url, "is invalid") unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    errors.add(:repository_url, "is invalid")
  end
end
