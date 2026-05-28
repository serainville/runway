# frozen_string_literal: true

require "tempfile"

require_relative "../lib/executor/env_loader"

RSpec.describe Executor::EnvLoader do
  it "loads key value pairs from a dotenv file" do
    Tempfile.create(["executor", ".env"]) do |file|
      file.write(<<~ENVFILE)
        # comment
        EXECUTOR_BIND_ADDRESS=127.0.0.1
        EXECUTOR_PORT="4111"
        export EXECUTOR_BACKEND_MODE=docker
      ENVFILE
      file.flush

      original_bind_address = ENV["EXECUTOR_BIND_ADDRESS"]
      original_port = ENV["EXECUTOR_PORT"]
      original_backend_mode = ENV["EXECUTOR_BACKEND_MODE"]

      begin
        ENV.delete("EXECUTOR_BIND_ADDRESS")
        ENV.delete("EXECUTOR_PORT")
        ENV.delete("EXECUTOR_BACKEND_MODE")

        expect(described_class.load!(path: file.path)).to eq(true)
        expect(ENV["EXECUTOR_BIND_ADDRESS"]).to eq("127.0.0.1")
        expect(ENV["EXECUTOR_PORT"]).to eq("4111")
        expect(ENV["EXECUTOR_BACKEND_MODE"]).to eq("docker")
      ensure
        ENV["EXECUTOR_BIND_ADDRESS"] = original_bind_address
        ENV["EXECUTOR_PORT"] = original_port
        ENV["EXECUTOR_BACKEND_MODE"] = original_backend_mode
      end
    end
  end

  it "returns false when the file is missing" do
    expect(described_class.load!(path: "/tmp/not-a-real-env-file")).to eq(false)
  end
end