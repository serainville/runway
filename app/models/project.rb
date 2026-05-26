class Project < ApplicationRecord
  has_many :project_memberships, dependent: :destroy
  has_many :applications, dependent: :destroy
  has_many :repository_connections, dependent: :destroy
  has_many :users, through: :project_memberships
  has_many :audit_events, as: :auditable, dependent: :nullify

  before_validation :set_slug

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: { case_sensitive: false }

  private

  def set_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end
end
