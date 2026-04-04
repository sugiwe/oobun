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

    // 保存完了後、Turbo経由で公開処理を実行（フラッシュメッセージを保持）
    const url = link.href

    // TurboのvisitメソッドでPOSTリクエストを送信
    // これによりフラッシュメッセージが正しく表示される
    Turbo.visit(url, {
      method: "post"
    })
  }
}
