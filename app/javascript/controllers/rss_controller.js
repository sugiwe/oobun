import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  static values = { url: String }

  toggle(event) {
    event.preventDefault()
    this.menuTarget.classList.toggle("hidden")
  }

  hide(event) {
    // メニュー外をクリックした時に閉じる
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
    }
  }

  copy(event) {
    event.preventDefault()
    const button = event.currentTarget
    const originalText = button.textContent.trim()

    navigator.clipboard.writeText(this.urlValue).then(() => {
      // ボタンのテキストを変更
      button.textContent = "コピーしました！"

      // 1.5秒後に元のテキストに戻し、メニューを閉じる
      setTimeout(() => {
        button.textContent = originalText
        this.menuTarget.classList.add("hidden")
      }, 1500)
    })
  }

  connect() {
    // ドキュメント全体のクリックイベントを監視
    this.boundHide = this.hide.bind(this)
    document.addEventListener("click", this.boundHide)
  }

  disconnect() {
    document.removeEventListener("click", this.boundHide)
  }
}
