import { Controller } from "@hotwired/stimulus"

// 下書きの自動保存コントローラー
// 入力内容を定期的にサーバーに保存し、データ損失を防ぐ
export default class extends Controller {
  static targets = ["title", "body", "status", "form"]
  static values = {
    url: String,
    interval: { type: Number, default: 3000 } // 3秒間隔
  }

  connect() {
    // 初期値を保存（変更検知用）
    this.savedTitle = this.titleTarget.value
    this.savedBody = this.bodyTarget.value

    // CSRF トークンを取得
    this.csrfToken = document.querySelector('[name="csrf-token"]')?.content

    // 保存中フラグ
    this.isSaving = false

    // debounce タイマー
    this.saveTimer = null

    // 初期ステータス表示
    this.updateStatus("入力内容は自動保存されます")
  }

  disconnect() {
    // タイマーをクリア
    if (this.saveTimer) {
      clearTimeout(this.saveTimer)
    }
  }

  // 入力時のハンドラー
  input() {
    // 変更がない場合はスキップ
    if (!this.hasChanges()) {
      return
    }

    // ステータス更新
    this.updateStatus("自動保存中...")

    // 既存のタイマーをクリア
    if (this.saveTimer) {
      clearTimeout(this.saveTimer)
    }

    // debounce: 一定時間後に保存
    this.saveTimer = setTimeout(() => {
      this.save()
    }, this.intervalValue)
  }

  // 変更があるかチェック
  hasChanges() {
    return this.titleTarget.value !== this.savedTitle ||
           this.bodyTarget.value !== this.savedBody
  }

  // サーバーに保存
  async save() {
    // 既に保存中の場合はスキップ
    if (this.isSaving) {
      return
    }

    // 変更がない場合はスキップ
    if (!this.hasChanges()) {
      return
    }

    this.isSaving = true
    this.updateStatus("保存中...")

    try {
      const formData = new FormData()
      formData.append("post[title]", this.titleTarget.value)
      formData.append("post[body]", this.bodyTarget.value)
      formData.append("post[status]", "draft") // 下書きとして保存

      const response = await fetch(this.urlValue, {
        method: "PATCH",
        body: formData,
        headers: {
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        }
      })

      if (response.ok) {
        // 保存成功
        this.savedTitle = this.titleTarget.value
        this.savedBody = this.bodyTarget.value
        this.updateStatus(`保存済み (${this.formatTime(new Date())})`)
      } else {
        // エラー時にレスポンスからエラーメッセージを取得
        const data = await response.json().catch(() => null)
        const errorMessage = data?.errors?.join("、") || "保存に失敗しました"
        this.updateStatus(`保存エラー: ${errorMessage}`)
      }
    } catch (error) {
      console.error("Autosave error:", error)
      this.updateStatus("保存エラー: ネットワークエラー")
    } finally {
      this.isSaving = false
    }
  }

  // ステータス表示を更新
  updateStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
    }
  }

  // 時刻フォーマット (HH:MM:SS)
  formatTime(date) {
    return date.toLocaleTimeString("ja-JP", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit"
    })
  }
}
