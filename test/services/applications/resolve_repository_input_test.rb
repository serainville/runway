require "test_helper"

class ApplicationsResolveRepositoryInputTest < ActiveSupport::TestCase
  test "returns manual repository url when input mode is manual" do
    result = Applications::ResolveRepositoryInput.call(
      repository_input_mode: "manual",
      repository_url: "https://gitlab.example.com/tenant/manual.git",
      selected_repository_url: "https://gitlab.example.com/tenant/selected.git"
    )

    assert result.success?
    assert_equal "https://gitlab.example.com/tenant/manual.git", result.repository_url
  end

  test "returns selected repository url when input mode is select" do
    result = Applications::ResolveRepositoryInput.call(
      repository_input_mode: "select",
      repository_url: "",
      selected_repository_url: "https://gitlab.example.com/tenant/selected.git"
    )

    assert result.success?
    assert_equal "https://gitlab.example.com/tenant/selected.git", result.repository_url
  end

  test "returns validation failure when selected mode has no selected repository url" do
    result = Applications::ResolveRepositoryInput.call(
      repository_input_mode: "select",
      repository_url: "",
      selected_repository_url: ""
    )

    assert_not result.success?
    assert_equal :validation_failed, result.error
    assert_includes result.message, "Select a repository"
  end
end
