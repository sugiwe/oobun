import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    // クリック外側でメニューを閉じる
    this.boundClose = this.closeOnClickOutside.bind(this)
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")

    if (!this.menuTarget.classList.contains("hidden")) {
      document.addEventListener("click", this.boundClose)
    } else {
      document.removeEventListener("click", this.boundClose)
    }
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
      document.removeEventListener("click", this.boundClose)
    }
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
  }
}
