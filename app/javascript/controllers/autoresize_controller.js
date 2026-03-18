import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.resize()
  }

  resize() {
    // 一旦高さをリセットして正確なscrollHeightを取得
    this.element.style.height = "auto"
    // scrollHeightに合わせて高さを設定
    this.element.style.height = this.element.scrollHeight + "px"
  }
}
