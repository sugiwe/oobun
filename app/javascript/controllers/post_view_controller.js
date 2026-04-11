import { Controller } from "@hotwired/stimulus"

// 投稿詳細ページのMarkdown/Plain表示切り替えコントローラー
export default class extends Controller {
  static targets = ["markdownArea", "plainArea", "markdownButton", "plainButton"]
  static values = {
    userId: Number  // ログインユーザーのID（ログインしていない場合は0）
  }

  connect() {
    // ページロード時にユーザー設定またはlocalStorageから表示モードを復元
    const savedMode = this.getSavedMode()
    if (savedMode === "plain") {
      this.showPlain()
    } else {
      this.showMarkdown()
    }
  }

  // Markdown表示に切り替え
  showMarkdown() {
    this.markdownAreaTarget.classList.remove("hidden")
    this.plainAreaTarget.classList.add("hidden")

    this.markdownButtonTarget.classList.add("border-gray-900", "text-gray-900")
    this.markdownButtonTarget.classList.remove("border-transparent", "text-gray-500")

    this.plainButtonTarget.classList.add("border-transparent", "text-gray-500")
    this.plainButtonTarget.classList.remove("border-gray-900", "text-gray-900")

    this.saveMode("markdown")
  }

  // Plain表示に切り替え
  showPlain() {
    this.plainAreaTarget.classList.remove("hidden")
    this.markdownAreaTarget.classList.add("hidden")

    this.plainButtonTarget.classList.add("border-gray-900", "text-gray-900")
    this.plainButtonTarget.classList.remove("border-transparent", "text-gray-500")

    this.markdownButtonTarget.classList.add("border-transparent", "text-gray-500")
    this.markdownButtonTarget.classList.remove("border-gray-900", "text-gray-900")

    this.saveMode("plain")
  }

  // モードを保存（ログインユーザーはAjax、非ログインはlocalStorage）
  saveMode(mode) {
    if (this.userIdValue > 0) {
      // ログインユーザー: Ajaxでサーバーに保存
      fetch("/settings/post_view", {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ preferred_post_view: mode })
      })
    } else {
      // 非ログインユーザー: localStorageに保存
      localStorage.setItem("preferredPostView", mode)
    }
  }

  // 保存されたモードを取得
  getSavedMode() {
    if (this.userIdValue > 0) {
      // ログインユーザー: data-default-modeから取得（サーバー側で設定）
      return this.element.dataset.defaultMode || "markdown"
    } else {
      // 非ログインユーザー: localStorageから取得
      return localStorage.getItem("preferredPostView") || "markdown"
    }
  }
}
