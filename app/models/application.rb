class Application < ApplicationRecord
  belongs_to :team, optional: true
  belongs_to :project, optional: true
  belongs_to :runtime_option, optional: true
  has_many :environments, dependent: :destroy
  has_many :audit_events, as: :auditable, dependent: :nullify
  has_one :repository_connection, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true
  validates :runtime, presence: true, if: :project_owned?
  validates :runtime_version, presence: true, if: :project_owned?

  validates :name, uniqueness: { scope: :team_id, case_sensitive: false }, if: :team_owned?
  validates :slug, uniqueness: { scope: :team_id, case_sensitive: false }, if: :team_owned?
  validates :name, uniqueness: { scope: :project_id, case_sensitive: false }, if: :project_owned?
  validates :slug, uniqueness: { scope: :project_id, case_sensitive: false }, if: :project_owned?

  validate :ownership_boundary_present

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
end
