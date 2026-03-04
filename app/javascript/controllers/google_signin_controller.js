import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.retries = 0
    this.maxRetries = 50 // 5秒待ってもロードされなければ諦める (50 * 100ms = 5000ms)
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
      if (this.retries < this.maxRetries) {
        this.retries++
        setTimeout(() => this.initializeGoogleSignIn(), 100)
      } else {
        console.error('Google Sign-In library failed to load after 5 seconds.')
      }
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

    // Google の CSRF トークンを取得（クッキーから）
    const gCsrfToken = this.getCookie('g_csrf_token')
    if (gCsrfToken) {
      const gCsrfInput = document.createElement('input')
      gCsrfInput.type = 'hidden'
      gCsrfInput.name = 'g_csrf_token'
      gCsrfInput.value = gCsrfToken
      form.appendChild(gCsrfInput)
    }

    const credentialInput = document.createElement('input')
    credentialInput.type = 'hidden'
    credentialInput.name = 'credential'
    credentialInput.value = response.credential
    form.appendChild(credentialInput)

    document.body.appendChild(form)
    form.submit()
  }

  getCookie(name) {
    const value = `; ${document.cookie}`
    const parts = value.split(`; ${name}=`)
    if (parts.length === 2) return parts.pop().split(';').shift()
    return null
  }
}
