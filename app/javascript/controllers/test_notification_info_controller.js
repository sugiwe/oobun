import { Controller } from "@hotwired/stimulus"

// テスト通知の案内をメール配信モードに応じて切り替える
// 上のフォーム内のラジオボタンの変更を検知して表示を切り替える
export default class extends Controller {
  static targets = ["info"]

  connect() {
    // ページ内のメール配信モードラジオボタンを監視
    const radioButtons = document.querySelectorAll('input[name="notification_setting[email_mode]"]')
    radioButtons.forEach(radio => {
      radio.addEventListener('change', () => this.updateInfo())
    })

    // 初期表示
    this.updateInfo()
  }

  updateInfo() {
    const selectedMode = document.querySelector('input[name="notification_setting[email_mode]"]:checked')?.value

    // 各案内の表示/非表示を切り替え
    this.infoTargets.forEach(target => {
      const targetMode = target.dataset.emailMode
      target.classList.toggle("hidden", targetMode !== selectedMode)
    })
  }
}
