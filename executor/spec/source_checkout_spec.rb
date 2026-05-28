# frozen_string_literal: true

require "fileutils"
require "shellwords"
require "tmpdir"

require_relative "../lib/executor/builds/source_checkout"

RSpec.describe Executor::Builds::SourceCheckout do
  it "clones the source repository into an isolated workspace and checks out the requested commit" do
    Dir.mktmpdir do |dir|
      repo_dir = File.join(dir, "source-repo")
      workspace_root = File.join(dir, "workspaces")
      FileUtils.mkdir_p(repo_dir)

      system("git", "init", repo_dir, exception: true)
      system("git", "-C", repo_dir, "config", "user.email", "dev@example.com", exception: true)
      system("git", "-C", repo_dir, "config", "user.name", "Dev User", exception: true)
      File.write(File.join(repo_dir, "README.md"), "hello from source checkout\n")
      system("git", "-C", repo_dir, "add", "README.md", exception: true)
      system("git", "-C", repo_dir, "commit", "-m", "initial commit", exception: true)

      commit_sha = `git -C #{repo_dir.shellescape} rev-parse HEAD`.strip

      command = {
        "command_id" => "cmd_build_123",
        "source" => {
          "repo_url" => repo_dir,
          "commit_sha" => commit_sha,
          "ref" => "main"
        }
      }

      result = described_class.new(workspace_root: workspace_root).call(command: command)

      expect(result.success?).to eq(true)
      expect(File).to exist(File.join(result.workdir, "README.md"))
      expect(File.read(File.join(result.workdir, "README.md"))).to include("hello from source checkout")
      expect(`git -C #{result.workdir.shellescape} rev-parse HEAD`.strip).to eq(commit_sha)
    end
  end

  it "logs clone and checkout progress" do
    Dir.mktmpdir do |dir|
      repo_dir = File.join(dir, "source-repo")
      workspace_root = File.join(dir, "workspaces")
      FileUtils.mkdir_p(repo_dir)

      system("git", "init", repo_dir, exception: true)
      system("git", "-C", repo_dir, "config", "user.email", "dev@example.com", exception: true)
      system("git", "-C", repo_dir, "config", "user.name", "Dev User", exception: true)
      File.write(File.join(repo_dir, "README.md"), "hello\n")
      system("git", "-C", repo_dir, "add", "README.md", exception: true)
      system("git", "-C", repo_dir, "commit", "-m", "initial commit", exception: true)

      commit_sha = `git -C #{repo_dir.shellescape} rev-parse HEAD`.strip

      command = {
        "command_id" => "cmd_build_456",
        "source" => {
          "repo_url" => repo_dir,
          "commit_sha" => commit_sha,
          "ref" => "main"
        }
      }

      expect do
        described_class.new(workspace_root: workspace_root).call(command: command)
      end.to output(/\[executor\] cloning source command_id=cmd_build_456.*\[executor\] source checkout ready command_id=cmd_build_456/m).to_stdout
    end
  end

  it "fails when the source repo url is missing" do
    result = described_class.new(workspace_root: "/tmp/runway-executor-test").call(command: {
      "command_id" => "cmd_build_123",
      "source" => { "commit_sha" => "abc123", "ref" => "main" }
    })

    expect(result.success?).to eq(false)
    expect(result.error).to eq(:invalid_source)
  end
end