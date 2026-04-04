import { Controller } from "@hotwired/stimulus"

// 下書きの自動保存コントローラー
// 入力内容を定期的にサーバーに保存し、データ損失を防ぐ
export default class extends Controller {
  static targets = ["title", "body", "status", "form"]
  static values = {
    url: String,
    interval: { type: Number, default: 1000 }, // 1秒間隔（debounce）
    maxInterval: { type: Number, default: 5000 } // 5秒間隔（強制保存）
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

    // カウントダウン用インターバル
    this.countdownInterval = null

    // 強制保存用タイマー
    this.forceSaveTimer = null

    // 最後の保存時刻
    this.lastSaveTime = Date.now()

    // 初期ステータス表示
    this.updateStatus("入力内容は自動保存されます")
  }

  disconnect() {
    // タイマーをクリア
    if (this.saveTimer) {
      clearTimeout(this.saveTimer)
    }
    if (this.countdownInterval) {
      clearInterval(this.countdownInterval)
    }
    if (this.forceSaveTimer) {
      clearTimeout(this.forceSaveTimer)
    }
  }

  // 入力時のハンドラー
  input() {
    // 変更がない場合はスキップ
    if (!this.hasChanges()) {
      return
    }

    // 既存のタイマーとカウントダウンをクリア
    if (this.saveTimer) {
      clearTimeout(this.saveTimer)
    }
    if (this.countdownInterval) {
      clearInterval(this.countdownInterval)
    }

    // 残り秒数を計算（ミリ秒 → 秒）
    const intervalSeconds = Math.ceil(this.intervalValue / 1000)
    let remainingSeconds = intervalSeconds

    // 初回表示
    this.updateStatus(`${remainingSeconds}秒後に自動保存...`)

    // 1秒ごとにカウントダウン
    this.countdownInterval = setInterval(() => {
      remainingSeconds--
      if (remainingSeconds > 0) {
        this.updateStatus(`${remainingSeconds}秒後に自動保存...`)
      } else {
        // カウントダウン終了時にクリア（save()が実行される直前）
        clearInterval(this.countdownInterval)
        this.countdownInterval = null
        // 「保存中...」は save() メソッド内で表示されるので、ここでは何もしない
      }
    }, 1000)

    // debounce: 一定時間後に保存
    this.saveTimer = setTimeout(() => {
      // カウントダウンをクリア（念のため）
      if (this.countdownInterval) {
        clearInterval(this.countdownInterval)
        this.countdownInterval = null
      }
      this.save()
    }, this.intervalValue)

    // 強制保存タイマーを設定（最後の保存から maxInterval 経過で発動）
    this.scheduleForceSave()
  }

  // 強制保存タイマーをスケジュール
  scheduleForceSave() {
    // 既存の強制保存タイマーをクリア
    if (this.forceSaveTimer) {
      clearTimeout(this.forceSaveTimer)
    }

    // 最後の保存からの経過時間を計算
    const timeSinceLastSave = Date.now() - this.lastSaveTime
    const timeUntilForceSave = Math.max(0, this.maxIntervalValue - timeSinceLastSave)

    // 強制保存タイマーを設定
    this.forceSaveTimer = setTimeout(() => {
      // debounce タイマーとカウントダウンをクリア
      if (this.saveTimer) {
        clearTimeout(this.saveTimer)
        this.saveTimer = null
      }
      if (this.countdownInterval) {
        clearInterval(this.countdownInterval)
        this.countdownInterval = null
      }

      // 変更がある場合のみ保存
      if (this.hasChanges()) {
        this.save()
      }
    }, timeUntilForceSave)
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
        this.lastSaveTime = Date.now() // 最後の保存時刻を更新
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

  // 投稿前に保存を確認（外部から呼び出し可能）
  async ensureSaved() {
    // 未保存の変更がある場合は保存
    if (this.hasChanges()) {
      await this.save()
    }
    return !this.hasChanges() // 保存成功したか確認
  }
}
