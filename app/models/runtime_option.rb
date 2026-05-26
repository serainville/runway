class RuntimeOption < ApplicationRecord
  has_many :applications, dependent: :restrict_with_error

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name, :version) }

  validates :name, presence: true, uniqueness: { scope: :version, case_sensitive: false }
  validates :version, presence: true
  validates :active, inclusion: { in: [true, false] }

  def display_name
    "#{name.to_s.capitalize} #{version}"
  end
end
