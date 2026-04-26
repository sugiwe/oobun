import { Controller } from "@hotwired/stimulus"

// テキストの展開・折りたたみを制御するコントローラー
export default class extends Controller {
  static targets = ["content"]

  connect() {
    // 初期状態: 折りたたまれている
    this.expanded = false
  }

  toggle() {
    this.expanded = !this.expanded

    if (this.expanded) {
      // 展開: line-clamp を削除
      this.contentTarget.classList.remove("line-clamp-2")
    } else {
      // 折りたたみ: line-clamp-2 を追加
      this.contentTarget.classList.add("line-clamp-2")
    }
  }
}
