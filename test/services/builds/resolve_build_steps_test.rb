require "test_helper"

class BuildsResolveBuildStepsTest < ActiveSupport::TestCase
  def make_app(build_template:)
    Application.create!(
      project: projects(:one),
      name: "Steps App #{build_template}",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/acme/steps-app.git",
      repository_connection: repository_connections(:project_one_gitlab),
      build_template: build_template
    )
  end

  def make_build(app)
    Build.create!(
      application: app,
      requested_by: users(:one),
      status: "pending",
      runtime_key: "ruby-4",
      source_ref: "main",
      commit_sha: "a" * 40
    )
  end

  test "returns one build step" do
    app = make_app(build_template: "buildkit")
    build = make_build(app)

    steps = Builds::ResolveBuildSteps.call(build: build)

    names = steps.map { |s| s[:name] }
    assert_equal %w[build], names
  end

  test "buildkit template produces a docker buildx build command" do
    app = make_app(build_template: "buildkit")
    build = make_build(app)

    steps = Builds::ResolveBuildSteps.call(build: build)
    build_step = steps.find { |s| s[:name] == "build" }

    assert build_step[:command].include?("docker"), "expected docker in buildkit build command"
    assert build_step[:command].include?("buildx"), "expected buildx in buildkit build command"
  end

  test "buildpacks template produces a pack build command" do
    app = make_app(build_template: "buildpacks")
    build = make_build(app)

    steps = Builds::ResolveBuildSteps.call(build: build)
    build_step = steps.find { |s| s[:name] == "build" }

    assert build_step[:command].include?("pack"), "expected pack in buildpacks build command"
    assert build_step[:command].include?("build"), "expected build in buildpacks build command"
  end

  test "build step only is returned regardless of template" do
    buildkit_app = make_app(build_template: "buildkit")
    buildpacks_app = make_app(build_template: "buildpacks")

    buildkit_steps = Builds::ResolveBuildSteps.call(build: make_build(buildkit_app))
    buildpacks_steps = Builds::ResolveBuildSteps.call(build: make_build(buildpacks_app))

    assert_equal ["build"], buildkit_steps.map { |step| step[:name] }
    assert_equal ["build"], buildpacks_steps.map { |step| step[:name] }
  end

  test "artifact image uses RUNWAY_ARTIFACT_REGISTRY when set" do
    app = make_app(build_template: "buildkit")
    build = make_build(app)
    previous = ENV["RUNWAY_ARTIFACT_REGISTRY"]
    ENV["RUNWAY_ARTIFACT_REGISTRY"] = "nexus.serverlab.intra"

    steps = Builds::ResolveBuildSteps.call(build: build)

    build_step = steps.find { |s| s[:name] == "build" }
    image = build_step[:command][build_step[:command].index("-t") + 1]
    assert image.start_with?("nexus.serverlab.intra/apps/"), "expected image to use configured artifact registry"
  ensure
    ENV["RUNWAY_ARTIFACT_REGISTRY"] = previous
  end

  test "artifact image falls back to executor .env artifact registry" do
    app = make_app(build_template: "buildkit")
    build = make_build(app)
    previous = ENV["RUNWAY_ARTIFACT_REGISTRY"]
    env_path = Rails.root.join("executor", ".env")
    original_executor_env = File.exist?(env_path) ? File.read(env_path) : nil
    ENV.delete("RUNWAY_ARTIFACT_REGISTRY")

    File.write(env_path, "RUNWAY_ARTIFACT_REGISTRY=nexus.serverlab.intra\n")

    steps = Builds::ResolveBuildSteps.call(build: build)
    build_step = steps.find { |s| s[:name] == "build" }
    image = build_step[:command][build_step[:command].index("-t") + 1]
    assert image.start_with?("nexus.serverlab.intra/apps/"), "expected image to use executor .env artifact registry"
  ensure
    ENV["RUNWAY_ARTIFACT_REGISTRY"] = previous
    if original_executor_env.nil?
      File.delete(env_path) if File.exist?(env_path)
    else
      File.write(env_path, original_executor_env)
    end
  end
end
