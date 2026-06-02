import { Controller } from "@hotwired/stimulus"

// アンカーリンク（同一ページ内のジャンプ）でのみsmooth scrollを適用する
export default class extends Controller {
  connect() {
    // ページ内のすべてのリンクをチェック
    document.addEventListener("click", this.handleClick.bind(this))
  }

  disconnect() {
    document.removeEventListener("click", this.handleClick.bind(this))
  }

  handleClick(event) {
    const link = event.target.closest("a")
    if (!link) return

    const href = link.getAttribute("href")
    if (!href) return

    // アンカーリンク（#で始まる）の場合のみsmooth scrollを適用
    if (href.startsWith("#")) {
      event.preventDefault()
      const targetId = href.substring(1)
      const targetElement = document.getElementById(targetId)

      if (targetElement) {
        targetElement.scrollIntoView({
          behavior: "smooth",
          block: "start"
        })
        // URLを更新（履歴に追加）
        history.pushState(null, null, href)
      }
    }
  }
}
