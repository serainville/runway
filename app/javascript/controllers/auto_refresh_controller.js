import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label"]

  static values = {
    enabled: { type: Boolean, default: true },
    interval: { type: Number, default: 5000 },
    frameId: String,
    framePath: String
  }

  connect() {
    if (!this.enabledValue) {
      this.renderLabel("Auto-refresh paused")
      return
    }

    this.lastUpdatedAt = Date.now()
    this.labelTimer = setInterval(() => {
      this.updateLabel()
    }, 1000)
    this.updateLabel()

    this.timer = setInterval(() => {
      if (document.hidden) {
        return
      }

      this.refresh()
    }, this.intervalValue)
  }

  disconnect() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }

    if (this.labelTimer) {
      clearInterval(this.labelTimer)
      this.labelTimer = null
    }
  }

  updateLabel() {
    const elapsedSeconds = Math.floor((Date.now() - this.lastUpdatedAt) / 1000)
    const updatedText = elapsedSeconds === 0 ? "just now" : `${elapsedSeconds}s ago`
    const intervalSeconds = Math.round(this.intervalValue / 1000)

    this.renderLabel(`Last updated ${updatedText}. Refresh every ${intervalSeconds}s.`)
  }

  renderLabel(text) {
    if (!this.hasLabelTarget) {
      return
    }

    this.labelTarget.textContent = text
  }

  refresh() {
    this.lastUpdatedAt = Date.now()

    if (this.hasFrameIdValue && this.hasFramePathValue) {
      const frame = document.getElementById(this.frameIdValue)
      if (frame) {
        const separator = this.framePathValue.includes("?") ? "&" : "?"
        frame.src = `${this.framePathValue}${separator}refresh=${Date.now()}`
        return
      }
    }

    window.location.reload()
  }
}
