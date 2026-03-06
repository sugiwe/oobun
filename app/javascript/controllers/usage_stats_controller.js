import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="usage-stats"
export default class extends Controller {
  connect() {
    // 画面幅768px以上（md以上）の場合は開く、それ以下は閉じる
    const isDesktop = window.matchMedia("(min-width: 768px)").matches
    this.element.open = isDesktop
  }
}
