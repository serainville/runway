class Build < ApplicationRecord
  STATUSES = %w[pending running failed_lint failed_tests failed_image succeeded canceled].freeze
  TERMINAL_STATUSES = %w[failed_lint failed_tests failed_image succeeded canceled].freeze
  TRIGGER_SOURCES = %w[manual webhook].freeze

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
  validates :trigger_source, presence: true, inclusion: { in: TRIGGER_SOURCES }

  scope :pending, -> { where(status: "pending") }

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  def container_repository_url
    parsed = parsed_container_artifact_reference
    return nil if parsed.nil?

    parsed[:repository_url]
  end

  def container_image_name
    parsed = parsed_container_artifact_reference
    return nil if parsed.nil?

    parsed[:image_name]
  end

  def container_tag_or_hash
    parsed = parsed_container_artifact_reference
    return nil if parsed.nil?

    parsed[:tag_or_hash]
  end

  def build_logs_truncated?
    build_log_chunks.any? { |entry| entry.chunk.to_s.include?("[TRUNCATED]") }
  end

  private

  def parsed_container_artifact_reference
    reference = artifact_reference.to_s.strip
    return nil if reference.empty?
    return nil if reference.include?("://")

    reference_without_digest, digest = reference.split("@", 2)
    tag = nil
    name_with_path = reference_without_digest

    slash_index = name_with_path.rindex("/")
    colon_index = name_with_path.rindex(":")
    if colon_index && (slash_index.nil? || colon_index > slash_index)
      tag = name_with_path[(colon_index + 1)..]
      name_with_path = name_with_path[0...colon_index]
    end

    segments = name_with_path.split("/")
    return nil if segments.length < 2

    registry = segments.first
    image_name = segments.last
    repository_path = segments[1..-2].join("/")
    repository_url = repository_path.empty? ? registry : "#{registry}/#{repository_path}"

    {
      repository_url: repository_url,
      image_name: image_name,
      tag_or_hash: tag.presence || digest.presence || commit_sha
    }
  end
end
