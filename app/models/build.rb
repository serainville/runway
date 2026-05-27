class Build < ApplicationRecord
  STATUSES = %w[pending running failed_lint failed_tests failed_image succeeded canceled].freeze
  TERMINAL_STATUSES = %w[failed_lint failed_tests failed_image succeeded canceled].freeze

  belongs_to :application
  belongs_to :requested_by, class_name: "User"
  belongs_to :build_integration, optional: true
  has_many :build_phase_events, dependent: :destroy
  has_many :build_log_chunks, dependent: :destroy
  has_many :build_host_request_events, dependent: :destroy
  has_many :audit_events, as: :auditable, dependent: :nullify

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :runtime_key, presence: true
  validates :source_ref, presence: true
  validates :commit_sha, presence: true

  scope :pending, -> { where(status: "pending") }

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end
end
