class Project < ApplicationRecord
  has_many :project_memberships, dependent: :destroy
  has_many :applications, dependent: :destroy
  has_many :repository_connections, dependent: :destroy
  has_many :users, through: :project_memberships
  has_many :audit_events, as: :auditable, dependent: :nullify

  before_validation :set_slug

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: { case_sensitive: false }
  validates :public, inclusion: { in: [true, false] }

  def role_for(user)
    return nil unless user

    project_memberships.find_by(user_id: user.id)&.role
  end

  def owner?(user)
    role_for(user) == "owner"
  end

  def contributor_or_owner?(user)
    role = role_for(user)
    role == "owner" || role == "contributor"
  end

  def visible_to?(user)
    return false unless user

    public? || role_for(user).present?
  end

  private

  def set_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end
end
