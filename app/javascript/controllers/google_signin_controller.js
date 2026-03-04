import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Google Sign-In ライブラリがロードされるまで待つ
    this.initializeGoogleSignIn()
  }

  initializeGoogleSignIn() {
    if (typeof google !== 'undefined' && google.accounts) {
      // ライブラリが既にロード済み
      google.accounts.id.initialize({
        client_id: this.element.dataset.clientId,
        callback: this.handleCredentialResponse.bind(this)
      })
      google.accounts.id.renderButton(
        this.element.querySelector('.g_id_signin'),
        {
          type: 'standard',
          size: 'large',
          text: 'signin_with',
          shape: 'rectangular',
          logo_alignment: 'left',
          width: 280
        }
      )
      // One Tap も再初期化
      const oneTapElement = this.element.querySelector('#g_id_onload')
      if (oneTapElement) {
        google.accounts.id.prompt()
      }
    } else {
      // ライブラリがまだロードされていない場合は少し待って再試行
      setTimeout(() => this.initializeGoogleSignIn(), 100)
    }
  }

  handleCredentialResponse(response) {
    // credential を hidden input に設定してフォーム送信
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = this.element.dataset.loginUri

    const csrfToken = document.querySelector('meta[name="csrf-token"]').content
    const csrfInput = document.createElement('input')
    csrfInput.type = 'hidden'
    csrfInput.name = 'authenticity_token'
    csrfInput.value = csrfToken
    form.appendChild(csrfInput)

    const credentialInput = document.createElement('input')
    credentialInput.type = 'hidden'
    credentialInput.name = 'credential'
    credentialInput.value = response.credential
    form.appendChild(credentialInput)

    document.body.appendChild(form)
    form.submit()
  }
}
