module Builds
  class AppendLogChunk
    Result = Struct.new(:success?, :log_chunk, :error, :message, keyword_init: true)

    MAX_CHUNK_LENGTH = 16_384
    CHUNK_TRUNCATION_SUFFIX = " ... [TRUNCATED]"

    REDACTION_PATTERNS = [
      /(password\s*[:=]\s*)\S+/i,
      /(token\s*[:=]\s*)\S+/i,
      /(secret\s*[:=]\s*)\S+/i,
      /(authorization\s*[:=]\s*bearer\s+)\S+/i,
      /(api[_-]?key\s*[:=]\s*)\S+/i
    ].freeze

    def self.call(build_id:, lease_id:, phase:, sequence:, chunk:, reported_at: Time.current)
      new(build_id: build_id, lease_id: lease_id, phase: phase, sequence: sequence, chunk: chunk, reported_at: reported_at).call
    end

    def initialize(build_id:, lease_id:, phase:, sequence:, chunk:, reported_at:)
      @build_id = build_id
      @lease_id = lease_id
      @phase = phase
      @sequence = sequence
      @chunk = chunk
      @reported_at = reported_at
    end

    def call
      build = Build.find_by(id: build_id)
      return Result.new(success?: false, error: :not_found, message: "Build not found") unless build
      return Result.new(success?: false, error: :conflict, message: "Lease conflict") unless build.lease_id == lease_id

      log_chunk = BuildLogChunk.find_or_initialize_by(build: build, phase: phase, sequence: sequence)
      if log_chunk.new_record?
        log_chunk.chunk = sanitize_chunk(chunk)
        log_chunk.reported_at = reported_at
        log_chunk.save!
      end

      Result.new(success?: true, log_chunk: log_chunk)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error: :validation_failed, message: e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :build_id, :lease_id, :phase, :sequence, :chunk, :reported_at

    def sanitize_chunk(value)
      text = redact(value.to_s)
      return text if text.length <= MAX_CHUNK_LENGTH

      allowed = MAX_CHUNK_LENGTH - CHUNK_TRUNCATION_SUFFIX.length
      "#{text[0, allowed]}#{CHUNK_TRUNCATION_SUFFIX}"
    end

    def redact(value)
      redacted = value.to_s
      REDACTION_PATTERNS.each do |pattern|
        redacted = redacted.gsub(pattern, "\\1[REDACTED]")
      end
      redacted
    end
  end
end
