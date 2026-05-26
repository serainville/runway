class Application < ApplicationRecord
  belongs_to :team
  has_many :environments, dependent: :destroy
  has_many :audit_events, as: :auditable, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :team_id, case_sensitive: false }
  validates :slug, presence: true, uniqueness: { scope: :team_id, case_sensitive: false }

  before_validation :set_slug

  private

  def set_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end
end
