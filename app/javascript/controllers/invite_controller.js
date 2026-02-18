import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "urlBox", "urlInput", "copyButton"]
  static values = { createUrl: String }

  async generate() {
    this.buttonTarget.disabled = true
    this.buttonTarget.textContent = "発行中..."

    try {
      const response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Accept": "application/json"
        }
      })

      if (!response.ok) throw new Error("招待URL発行に失敗しました")

      const data = await response.json()
      this.urlInputTarget.value = data.url
      this.urlBoxTarget.classList.remove("hidden")
      this.buttonTarget.classList.add("hidden")
    } catch (e) {
      alert(e.message)
      this.buttonTarget.disabled = false
      this.buttonTarget.textContent = "招待URLを発行"
    }
  }

  async copy() {
    await navigator.clipboard.writeText(this.urlInputTarget.value)
    this.copyButtonTarget.textContent = "コピーしました！"
    setTimeout(() => {
      this.copyButtonTarget.textContent = "コピー"
    }, 2000)
  }
}
