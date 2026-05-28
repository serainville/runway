# frozen_string_literal: true

require "fileutils"
require "open3"
require "shellwords"

module Executor
  module Builds
    class SourceCheckout
      Result = Struct.new(:success?, :workdir, :error, :message, keyword_init: true)

      def initialize(workspace_root: Executor::Config.docker_workdir)
        @workspace_root = workspace_root
      end

      def call(command:)
        source = command.fetch("source", {})
        repo_url = source["repo_url"].to_s.strip
        commit_sha = source["commit_sha"].to_s.strip
        return failure(:invalid_source, "Source repository URL is missing") if repo_url.empty?
        return failure(:invalid_source, "Source commit SHA is missing") if commit_sha.empty?

        workdir = File.join(workspace_root, safe_command_id(command.fetch("command_id")))
        FileUtils.rm_rf(workdir)
        FileUtils.mkdir_p(workspace_root)

        puts "[executor] cloning source command_id=#{command.fetch('command_id')} repo_url=#{repo_url} commit_sha=#{commit_sha} workdir=#{workdir}"

        checkout_repo(repo_url: repo_url, commit_sha: commit_sha, workdir: workdir)
        puts "[executor] source checkout ready command_id=#{command.fetch('command_id')} workdir=#{workdir}"
        Result.new(success?: true, workdir: workdir)
      rescue StandardError => e
        FileUtils.rm_rf(workdir) if defined?(workdir) && workdir
        failure(:source_fetch_failed, "Failed to fetch source: #{e.message}")
      end

      private

      attr_reader :workspace_root

      def checkout_repo(repo_url:, commit_sha:, workdir:)
        puts "[executor] git clone #{Shellwords.shelljoin(['git', 'clone', '--quiet', repo_url, workdir])}"
        run_git!("clone", "--quiet", repo_url, workdir)
        puts "[executor] git checkout #{Shellwords.shelljoin(['git', '-C', workdir, 'checkout', '--quiet', '--force', commit_sha])}"
        run_git!("-C", workdir, "checkout", "--quiet", "--force", commit_sha)
      end

      def run_git!(*args)
        stdout, stderr, status = Open3.capture3("git", *args)
        return if status.success?

        message = [stdout, stderr].join("\n").strip
        raise message.empty? ? "git #{args.join(' ')} failed" : message
      end

      def safe_command_id(command_id)
        command_id.to_s.gsub(/[^A-Za-z0-9._-]/, "_")
      end

      def failure(error, message)
        Result.new(success?: false, error: error, message: message)
      end
    end
  end
end