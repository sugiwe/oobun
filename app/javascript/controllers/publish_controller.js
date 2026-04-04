import { Controller } from "@hotwired/stimulus"

// 投稿公開時に自動保存を確認するコントローラー
export default class extends Controller {
  static targets = ["link"]

  async publish(event) {
    event.preventDefault()

    const link = event.currentTarget
    const autosaveController = this.application.getControllerForElementAndIdentifier(
      this.element,
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

    // 保存完了後、フォームを作成してPOST送信（フラッシュメッセージを保持）
    const url = link.href
    const csrfToken = document.querySelector('[name="csrf-token"]')?.content

    // 隠しフォームを作成してPOST送信
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = url

    // CSRFトークンを追加
    const csrfInput = document.createElement('input')
    csrfInput.type = 'hidden'
    csrfInput.name = 'authenticity_token'
    csrfInput.value = csrfToken
    form.appendChild(csrfInput)

    // フォームをDOMに追加して送信
    document.body.appendChild(form)
    form.submit()
  }
}
