import { Controller } from "@hotwired/stimulus"

// 投稿公開時に自動保存を確認するコントローラー
export default class extends Controller {
  static targets = ["link"]

  async publish(event) {
    event.preventDefault()

    const link = event.currentTarget
    const autosaveController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller~="draft-autosave"]'),
      "draft-autosave"
    )

    // 自動保存コントローラーが存在する場合は保存を確認
    if (autosaveController) {
      // 未保存の変更がある場合は保存
      const saved = await autosaveController.ensureSaved()

      if (!saved) {
        // 保存失敗の場合は公開を中止
        alert("下書きの保存に失敗しました。もう一度お試しください。")
        return
      }
    }

    // 保存完了後、または自動保存が不要な場合は公開処理を実行
    // Turboを使ってPOSTリクエストを送信
    const url = link.href
    const csrfToken = document.querySelector('[name="csrf-token"]')?.content

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
        },
        redirect: "follow"
      })

      if (response.redirected) {
        // リダイレクト先にページ遷移
        window.location.href = response.url
      } else if (response.ok) {
        // Turbo Streamレスポンスの場合は自動的に処理される
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      } else {
        // エラーレスポンスの場合
        const html = await response.text()
        document.body.innerHTML = html
      }
    } catch (error) {
      console.error("Publish error:", error)
      alert("投稿に失敗しました。もう一度お試しください。")
    }
  }
}
