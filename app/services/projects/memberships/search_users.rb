module Projects
  module Memberships
    class SearchUsers
      Result = Struct.new(:success?, :users, :error, :message, keyword_init: true)

      MAX_RESULTS = 6
      MIN_QUERY_LENGTH = 2

      def self.call(actor:, project:, query:)
        new(actor: actor, project: project, query: query).call
      end

      def initialize(actor:, project:, query:)
        @actor = actor
        @project = project
        @query = query.to_s.strip.downcase
      end

      def call
        return forbidden unless authorized?
        return Result.new(success?: true, users: []) if query.length < MIN_QUERY_LENGTH

        users = User
          .where("username LIKE ?", "%#{sanitize_query(query)}%")
          .order(:username)
          .limit(MAX_RESULTS)
          .map { |user| { id: user.id, username: user.username, name: user.name } }

        Result.new(success?: true, users: users)
      end

      private

      attr_reader :actor, :project, :query

      def authorized?
        Projects::AuthorizeAccess.call(actor: actor, project: project, action: :manage_members)
      end

      def sanitize_query(value)
        value.gsub(/[\\%_]/) { |char| "\\#{char}" }
      end

      def forbidden
        Result.new(success?: false, users: [], error: :forbidden, message: "Not authorized")
      end
    end
  end
end
