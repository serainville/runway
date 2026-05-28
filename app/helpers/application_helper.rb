module ApplicationHelper
  USER_AVATAR_BRAND_COLORS = [
    "#d946ef", # fuchsia-500
    "#c026d3", # fuchsia-600
    "#a21caf", # fuchsia-700
    "#3b82f6", # blue-500
    "#2563eb", # blue-600
    "#1d4ed8", # blue-700
    "#8b5cf6", # violet-500
    "#7c3aed", # violet-600
    "#6366f1", # indigo-500
    "#0ea5e9", # sky-500
    "#0284c7", # sky-600
    "#14b8a6"  # teal-500
  ].freeze

  def user_profile_display_name(user)
    user.name.presence || user.username
  end

  def user_avatar_initials(user)
    name_parts = user.name.to_s.strip.split(/\s+/).reject(&:blank?)
    if name_parts.size >= 2
      "#{name_parts.first[0]}#{name_parts.last[0]}".upcase
    else
      user.username.to_s.strip[0, 2].to_s.upcase
    end
  end

  def user_avatar_style(user)
    seed_source = [user.id, user.username, user.email].compact.join("-")
    color = USER_AVATAR_BRAND_COLORS[seed_source.each_byte.sum % USER_AVATAR_BRAND_COLORS.length]

    "background-color: #{color};"
  end

  def can_read_project?(project)
    Projects::AuthorizeAccess.call(actor: current_user, project: project, action: :read)
  end

  def can_manage_project_settings?(project)
    Projects::AuthorizeAccess.call(actor: current_user, project: project, action: :manage_settings)
  end

  def can_manage_project_members?(project)
    Projects::AuthorizeAccess.call(actor: current_user, project: project, action: :manage_members)
  end

  def can_initiate_build_for_project?(project)
    Projects::AuthorizeAccess.call(actor: current_user, project: project, action: :initiate_build)
  end

  def application_runtime_label(application)
    runtime_key = runtime_key_for(application)
    runtime_item = Runtimes::Catalog.find(runtime_key)
    return runtime_item.display_name if runtime_item

    [application.runtime.to_s.capitalize, application.runtime_version].compact_blank.join(" ")
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

  def build_status_badge_classes(status)
    case status
    when "succeeded"
      "border-emerald-300 bg-emerald-100 text-emerald-700 dark:border-emerald-400/20 dark:bg-emerald-500/10 dark:text-emerald-200"
    when "running", "pending"
      "border-blue-300 bg-blue-100 text-blue-700 dark:border-blue-400/20 dark:bg-blue-500/10 dark:text-blue-200"
    else
      "border-rose-300 bg-rose-100 text-rose-700 dark:border-rose-400/20 dark:bg-rose-500/10 dark:text-rose-200"
    end
  end

  def build_status_with_icon(status)
    content_tag(:span, class: "inline-flex items-center gap-1.5") do
      safe_join([build_status_icon(status), content_tag(:span, status.to_s.humanize)])
    end
  end

  def build_status_icon(status)
    case status.to_s
    when "running"
      raw("<svg viewBox='0 0 20 20' fill='none' class='h-3.5 w-3.5 animate-spin' aria-hidden='true'><circle cx='10' cy='10' r='7' stroke='currentColor' stroke-opacity='0.35' stroke-width='2'/><path d='M10 3a7 7 0 0 1 7 7' stroke='currentColor' stroke-width='2' stroke-linecap='round'/></svg>")
    when "pending"
      raw("<svg viewBox='0 0 20 20' fill='none' class='h-3.5 w-3.5' aria-hidden='true'><circle cx='10' cy='10' r='7' stroke='currentColor' stroke-width='2'/><path d='M10 6v4l3 2' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'/></svg>")
    when "succeeded"
      raw("<svg viewBox='0 0 20 20' fill='currentColor' class='h-3.5 w-3.5' aria-hidden='true'><path fill-rule='evenodd' d='M16.704 5.29a1 1 0 0 1 .006 1.414l-7.25 7.312a1 1 0 0 1-1.42-.005L3.29 9.19a1 1 0 1 1 1.42-1.407l4.04 4.075 6.54-6.562a1 1 0 0 1 1.414-.006Z' clip-rule='evenodd'/></svg>")
    else
      raw("<svg viewBox='0 0 20 20' fill='none' class='h-3.5 w-3.5' aria-hidden='true'><circle cx='10' cy='10' r='7' stroke='currentColor' stroke-width='2'/><path d='M7 7l6 6M13 7l-6 6' stroke='currentColor' stroke-width='2' stroke-linecap='round'/></svg>")
    end
  end

  def executor_registration_status_badge(integration)
    status = integration.executor_heartbeat_status
    classes = executor_registration_status_badge_classes(status)

    content_tag(:span, class: "inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-medium #{classes}") do
      safe_join([executor_registration_status_icon(status), content_tag(:span, status.humanize)])
    end
  end

  def executor_registration_status_badge_classes(status)
    case status
    when "online"
      "border-emerald-300 bg-emerald-100 text-emerald-700 dark:border-emerald-400/20 dark:bg-emerald-500/10 dark:text-emerald-200"
    when "offline"
      "border-rose-300 bg-rose-100 text-rose-700 dark:border-rose-400/20 dark:bg-rose-500/10 dark:text-rose-200"
    else
      "border-amber-300 bg-amber-100 text-amber-700 dark:border-amber-400/20 dark:bg-amber-500/10 dark:text-amber-200"
    end
  end

  def executor_registration_status_icon(status)
    case status
    when "online"
      raw("<svg viewBox='0 0 20 20' fill='currentColor' class='h-3.5 w-3.5' aria-hidden='true'><circle cx='10' cy='10' r='6'/></svg>")
    when "offline"
      raw("<svg viewBox='0 0 20 20' fill='currentColor' class='h-3.5 w-3.5' aria-hidden='true'><circle cx='10' cy='10' r='6'/></svg>")
    else
      raw("<svg viewBox='0 0 20 20' fill='none' class='h-3.5 w-3.5' aria-hidden='true'><path d='M10 3 3 17h14L10 3Z' stroke='currentColor' stroke-width='1.8' stroke-linejoin='round'/><path d='M10 8v4' stroke='currentColor' stroke-width='1.8' stroke-linecap='round'/><circle cx='10' cy='14' r='1' fill='currentColor'/></svg>")
    end
  end

  def executor_activation_badge(integration)
    active = integration.active?
    classes = if active
      "border-emerald-300 bg-emerald-100 text-emerald-700 dark:border-emerald-400/20 dark:bg-emerald-500/10 dark:text-emerald-200"
    else
      "border-slate-300 bg-slate-100 text-slate-700 dark:border-slate-400/30 dark:bg-slate-500/10 dark:text-slate-200"
    end

    label = active ? "Active" : "Deactivated"
    content_tag(:span, label, class: "inline-flex items-center rounded-full border px-2.5 py-1 text-xs font-medium #{classes}")
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
