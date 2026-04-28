import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progress"]
  static values = {
    type: String,
    duration: { type: Number, default: 4000 } // 4秒
  }

  connect() {
    this.startAutoHide()
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  startAutoHide() {
    // プログレスバーのアニメーション
    if (this.hasProgressTarget) {
      this.progressTarget.style.transition = `width ${this.durationValue}ms linear`
      this.progressTarget.style.width = "100%"

      // アニメーション開始（次のフレームで実行）
      requestAnimationFrame(() => {
        this.progressTarget.style.width = "0%"
      })
    }

    // 4秒後にフェードアウト
    this.timeout = setTimeout(() => {
      this.element.style.transition = "opacity 300ms ease-out"
      this.element.style.opacity = "0"

      // フェードアウト完了後に要素を削除
      setTimeout(() => {
        this.element.remove()
      }, 300)
    }, this.durationValue)
  }

  // 手動で閉じる（将来的に×ボタンを追加する場合）
  close() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
    this.element.style.transition = "opacity 300ms ease-out"
    this.element.style.opacity = "0"
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}
