import { Controller } from "@hotwired/stimulus"

// ラジオボタンの選択に応じて、設定項目の表示/非表示を切り替える
export default class extends Controller {
  static targets = ["digestSettings", "realtimeSettings"]

  connect() {
    this.toggle()
  }

  toggle() {
    const selectedMode = this.element.querySelector('input[name="notification_setting[email_mode]"]:checked')?.value

    // ダイジェスト設定の表示/非表示
    if (this.hasDigestSettingsTarget) {
      this.digestSettingsTarget.classList.toggle("hidden", selectedMode !== "digest")
    }

    // 即時配信設定の表示/非表示
    if (this.hasRealtimeSettingsTarget) {
      this.realtimeSettingsTarget.classList.toggle("hidden", selectedMode !== "realtime")
    }
  }
}
