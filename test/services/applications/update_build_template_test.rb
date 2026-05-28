require "test_helper"

class ApplicationsUpdateBuildTemplateTest < ActiveSupport::TestCase
  def make_app
    Application.create!(
      project: projects(:one),
      name: "Template App",
      runtime: "ruby",
      runtime_version: "4",
      repository_url: "https://gitlab.example.com/acme/template-app.git",
      repository_connection: repository_connections(:project_one_gitlab),
      build_template: "buildkit"
    )
  end

  test "owner can update build_template to buildpacks" do
    app = make_app

    result = Applications::UpdateBuildTemplate.call(
      actor: users(:one),
      project: projects(:one),
      application: app,
      build_template: "buildpacks"
    )

    assert result.success?
    assert_equal "buildpacks", app.reload.build_template
  end

  test "owner can update build_template to buildkit" do
    app = make_app
    app.update!(build_template: "buildpacks")

    result = Applications::UpdateBuildTemplate.call(
      actor: users(:one),
      project: projects(:one),
      application: app,
      build_template: "buildkit"
    )

    assert result.success?
    assert_equal "buildkit", app.reload.build_template
  end

  test "emits an audit event on successful update" do
    app = make_app

    assert_difference "AuditEvent.count", 1 do
      Applications::UpdateBuildTemplate.call(
        actor: users(:one),
        project: projects(:one),
        application: app,
        build_template: "buildpacks"
      )
    end

    event = AuditEvent.last
    assert_equal "application.build_template.updated", event.action
    assert_equal "buildpacks", event.metadata["build_template"]
    assert_equal "buildkit", event.metadata["previous_build_template"]
  end

  test "returns forbidden for non-project-member" do
    app = make_app

    result = Applications::UpdateBuildTemplate.call(
      actor: users(:two),
      project: projects(:one),
      application: app,
      build_template: "buildpacks"
    )

    assert_not result.success?
    assert_equal :forbidden, result.error
    assert_equal "buildkit", app.reload.build_template
  end

  test "returns validation failure for invalid build_template" do
    app = make_app

    result = Applications::UpdateBuildTemplate.call(
      actor: users(:one),
      project: projects(:one),
      application: app,
      build_template: "invalid_strategy"
    )

    assert_not result.success?
    assert_equal :validation_failed, result.error
    assert_equal "buildkit", app.reload.build_template
  end

  test "does not emit audit event on failure" do
    app = make_app

    assert_no_difference "AuditEvent.count" do
      Applications::UpdateBuildTemplate.call(
        actor: users(:two),
        project: projects(:one),
        application: app,
        build_template: "buildpacks"
      )
    end
  end
end
