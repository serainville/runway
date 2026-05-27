import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modeInput",
    "connectionSelect",
    "manualWrapper",
    "manualUrlInput",
    "selectWrapper",
    "availableRepositoriesSelect",
    "statusContainer",
    "statusIcon",
    "statusText"
  ]

  static values = {
    discoverUrl: String,
    verifyUrl: String
  }

  connect() {
    this.applyMode()
  }

  setMode(event) {
    this.modeInputTarget.value = event.target.value
    this.applyMode()
    this.clearStatus()

    if (this.modeInputTarget.value === "select") {
      this.loadRepositories()
    }
  }

  connectionChanged() {
    this.clearStatus()
    if (this.modeInputTarget.value === "select") {
      this.loadRepositories()
    }
  }

  async verify() {
    const repositoryConnectionId = this.connectionSelectTarget.value
    if (!repositoryConnectionId) {
      this.renderStatus("warning", "Select a repository connection before verifying")
      return
    }

    const repositoryInputMode = this.modeInputTarget.value || "manual"
    const repositoryUrl = this.manualUrlInputTarget.value
    const selectedRepositoryUrl = this.availableRepositoriesSelectTarget.value

    if (repositoryInputMode === "manual" && !repositoryUrl) {
      this.renderStatus("warning", "Enter a repository URL before verifying")
      return
    }

    if (repositoryInputMode === "select" && !selectedRepositoryUrl) {
      this.renderStatus("warning", "Select a repository before verifying")
      return
    }

    const body = new URLSearchParams({
      repository_connection_id: repositoryConnectionId,
      repository_input_mode: repositoryInputMode,
      repository_url: repositoryUrl,
      selected_repository_url: selectedRepositoryUrl
    })

    try {
      const response = await fetch(this.verifyUrlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": this.csrfToken(),
          "Content-Type": "application/x-www-form-urlencoded",
          "Accept": "application/json"
        },
        body
      })

      const payload = await response.json()
      if (response.ok && payload.success) {
        if (payload.repository_url) {
          this.manualUrlInputTarget.value = payload.repository_url
        }
        this.renderStatus("verified", payload.message || "Repository verified")
      } else {
        this.renderStatus("error", payload.message || "Runway could not verify repository access")
      }
    } catch (_error) {
      this.renderStatus("error", "Runway could not verify repository access")
    }
  }

  async loadRepositories() {
    const repositoryConnectionId = this.connectionSelectTarget.value
    this.availableRepositoriesSelectTarget.innerHTML = "<option value=''>Choose a repository</option>"

    if (!repositoryConnectionId) {
      this.renderStatus("warning", "Select a repository connection to load available repositories")
      return
    }

    const params = new URLSearchParams({ repository_connection_id: repositoryConnectionId })

    try {
      const response = await fetch(`${this.discoverUrlValue}?${params.toString()}`, {
        headers: { "Accept": "application/json" }
      })
      const payload = await response.json()

      if (!response.ok || !payload.success) {
        this.renderStatus("warning", payload.message || "Runway could not load available repositories")
        return
      }

      payload.repositories.forEach((repository) => {
        const option = document.createElement("option")
        option.value = repository.url
        option.textContent = repository.name
        this.availableRepositoriesSelectTarget.appendChild(option)
      })

      if (payload.repositories.length === 0) {
        this.renderStatus("warning", "No repositories were found for this connection")
      } else {
        this.renderStatus("warning", "Choose a repository and verify access")
      }
    } catch (_error) {
      this.renderStatus("warning", "Runway could not load available repositories")
    }
  }

  applyMode() {
    const selectedMode = this.modeInputTarget.value || "manual"
    const selectMode = selectedMode === "select"

    this.manualWrapperTarget.classList.toggle("hidden", selectMode)
    this.selectWrapperTarget.classList.toggle("hidden", !selectMode)
    this.manualUrlInputTarget.required = !selectMode
    this.availableRepositoriesSelectTarget.required = selectMode
  }

  clearStatus() {
    this.statusContainerTarget.classList.add("hidden")
    this.statusContainerTarget.classList.remove("inline-flex")
    this.statusTextTarget.textContent = ""
    this.statusIconTarget.innerHTML = ""
  }

  renderStatus(type, message) {
    this.statusContainerTarget.classList.remove("hidden")
    this.statusContainerTarget.classList.add("inline-flex")
    this.statusContainerTarget.classList.remove("border-emerald-300", "text-emerald-700", "border-amber-300", "text-amber-700", "border-rose-300", "text-rose-700")

    if (type === "verified") {
      this.statusContainerTarget.classList.add("border-emerald-300", "text-emerald-700")
      this.statusIconTarget.innerHTML = this.icon("verified")
    } else if (type === "warning") {
      this.statusContainerTarget.classList.add("border-amber-300", "text-amber-700")
      this.statusIconTarget.innerHTML = this.icon("warning")
    } else {
      this.statusContainerTarget.classList.add("border-rose-300", "text-rose-700")
      this.statusIconTarget.innerHTML = this.icon("error")
    }

    this.statusTextTarget.textContent = message
  }

  icon(type) {
    if (type === "verified") {
      return "<svg viewBox='0 0 20 20' fill='currentColor' class='h-4 w-4' aria-hidden='true'><path fill-rule='evenodd' d='M16.704 5.29a1 1 0 0 1 .006 1.414l-7.25 7.312a1 1 0 0 1-1.42-.005L3.29 9.19a1 1 0 1 1 1.42-1.407l4.04 4.075 6.54-6.562a1 1 0 0 1 1.414-.006Z' clip-rule='evenodd'/></svg>"
    }

    return "<svg viewBox='0 0 20 20' fill='currentColor' class='h-4 w-4' aria-hidden='true'><path fill-rule='evenodd' d='M8.257 3.099c.765-1.36 2.72-1.36 3.486 0l6.516 11.582c.75 1.334-.213 2.994-1.742 2.994H3.483c-1.53 0-2.493-1.66-1.742-2.994L8.257 3.1ZM10 7a1 1 0 0 0-1 1v3a1 1 0 1 0 2 0V8a1 1 0 0 0-1-1Zm0 8a1.25 1.25 0 1 0 0-2.5A1.25 1.25 0 0 0 10 15Z' clip-rule='evenodd'/></svg>"
  }

  csrfToken() {
    const token = document.querySelector("meta[name='csrf-token']")
    return token ? token.content : ""
  }
}
