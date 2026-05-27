module Applications
  class ResolveRepositoryInput
    Result = Struct.new(:success?, :repository_url, :error, :message, keyword_init: true)

    def self.call(repository_input_mode:, repository_url:, selected_repository_url:)
      mode = repository_input_mode.to_s.presence || "manual"

      resolved_url = if mode == "select"
        selected_repository_url.to_s.strip
      else
        repository_url.to_s.strip
      end

      if resolved_url.blank?
        message = mode == "select" ? "Select a repository from the available repositories list" : "Repository URL cannot be blank"
        return Result.new(success?: false, error: :validation_failed, message: message)
      end

      Result.new(success?: true, repository_url: resolved_url)
    end
  end
end
