import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["renderedTab", "rawTab", "renderedArea", "rawArea"]

  showRendered(event) {
    event.preventDefault()

    // タブのスタイル切り替え
    this.renderedTabTarget.classList.add("border-gray-900", "text-gray-900")
    this.renderedTabTarget.classList.remove("border-transparent", "text-gray-500")
    this.rawTabTarget.classList.add("border-transparent", "text-gray-500")
    this.rawTabTarget.classList.remove("border-gray-900", "text-gray-900")

    // エリアの表示切り替え
    this.renderedAreaTarget.classList.remove("hidden")
    this.rawAreaTarget.classList.add("hidden")
  }

  showRaw(event) {
    event.preventDefault()

    // タブのスタイル切り替え
    this.rawTabTarget.classList.add("border-gray-900", "text-gray-900")
    this.rawTabTarget.classList.remove("border-transparent", "text-gray-500")
    this.renderedTabTarget.classList.add("border-transparent", "text-gray-500")
    this.renderedTabTarget.classList.remove("border-gray-900", "text-gray-900")

    // エリアの表示切り替え
    this.rawAreaTarget.classList.remove("hidden")
    this.renderedAreaTarget.classList.add("hidden")
  }
}
