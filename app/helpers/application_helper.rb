module ApplicationHelper
  def application_runtime_label(application)
    [application.runtime, application.runtime_version].compact_blank.join(" ")
  end

  def application_runtime_with_icon(application, container_class: nil, icon_class: "h-5 w-5")
    classes = ["inline-flex items-center gap-2", container_class].compact.join(" ")

    content_tag(:span, class: classes) do
      runtime_icon_for_key(runtime_key_for(application), icon_class: icon_class) +
        content_tag(:span, application_runtime_label(application))
    end
  end

  def runtime_icon_for_key(runtime_key, icon_class: "h-5 w-5")
    image_tag(runtime_icon_path_for_key(runtime_key), alt: "", class: "#{icon_class} shrink-0", role: "presentation", aria: { hidden: true })
  end

  def application_state(application)
    return "Ready" if application.repository_connection.present? && application.environments.any? { |environment| environment.default? && environment.deployment_target.present? }

    "Needs setup"
  end

  def application_state_badge_classes(application)
    if application_state(application) == "Ready"
      "border-emerald-300 bg-emerald-100 text-emerald-700 dark:border-emerald-400/20 dark:bg-emerald-500/10 dark:text-emerald-200"
    else
      "border-amber-300 bg-amber-100 text-amber-700 dark:border-amber-400/20 dark:bg-amber-500/10 dark:text-amber-200"
    end
  end

  def project_summary_state(project)
    project.applications.all? { |application| application_state(application) == "Ready" } ? "Healthy" : "Needs attention"
  end

  def project_summary_state_classes(project)
    if project_summary_state(project) == "Healthy"
      "border-emerald-300 bg-emerald-100 text-emerald-700 dark:border-emerald-400/20 dark:bg-emerald-500/10 dark:text-emerald-200"
    else
      "border-amber-300 bg-amber-100 text-amber-700 dark:border-amber-400/20 dark:bg-amber-500/10 dark:text-amber-200"
    end
  end

  private

  def runtime_key_for(application)
    [application.runtime.to_s.downcase, application.runtime_version.to_s].reject(&:blank?).join("-")
  end

  def runtime_icon_path_for_key(runtime_key)
    key = runtime_key.to_s

    case key
    when "ruby-4"
      "/ruby-icon.svg"
    when "rails-8"
      "/rails-icon.svg"
    when "go", "golang"
      "/go-icon.svg"
    when "react", "reactjs"
      "/react-icon.svg"
    else
      return "/go-icon.svg" if key.start_with?("go-")
      return "/react-icon.svg" if key.start_with?("react-")

      "runtimes/default.svg"
    end
  end
end
