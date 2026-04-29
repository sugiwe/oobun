import { Controller } from "@hotwired/stimulus"

// 投稿公開時に自動保存を確認するコントローラー
export default class extends Controller {
  static targets = ["link"]

  async publish(event) {
    event.preventDefault()

    const link = event.currentTarget
    const publishUrl = link.href
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

    // サムネイル画像が選択されているかチェック
    const thumbnailInput = this.element.querySelector('input[type="file"][name="post[thumbnail]"]')
    const hasThumbnailSelected = thumbnailInput && thumbnailInput.files.length > 0

    if (hasThumbnailSelected) {
      // 画像が選択されている場合は、先にフォーム全体を送信して画像をアップロード
      const thumbnailSaved = await this.saveDraftWithThumbnail()
      if (!thumbnailSaved) {
        return // エラー時は中断
      }
      // 画像保存後、そのまま公開処理に進む
    }

    // 公開処理を実行
    this.submitPublish(publishUrl)
  }

  async saveDraftWithThumbnail() {
    // 元のフォームを取得
    const form = this.element.querySelector('form')
    if (!form) {
      alert("フォームが見つかりませんでした")
      return false
    }

    // サムネイル input を取得
    const thumbnailInput = this.element.querySelector('input[type="file"][name="post[thumbnail]"]')
    if (!thumbnailInput || !thumbnailInput.files.length) {
      // 画像が選択されていない（念のためのチェック）
      return true
    }

    // FormData を手動で構築
    const formData = new FormData()

    // タイトルと本文を追加
    const titleInput = form.querySelector('input[name="post[title]"]')
    const bodyInput = form.querySelector('textarea[name="post[body]"]')

    if (titleInput) {
      formData.append('post[title]', titleInput.value)
    }
    if (bodyInput) {
      formData.append('post[body]', bodyInput.value)
    }

    // サムネイル画像を追加
    formData.append('post[thumbnail]', thumbnailInput.files[0])

    // デバッグ: FormData の中身を確認
    console.log("FormData contents:")
    for (let [key, value] of formData.entries()) {
      console.log(key, value)
    }

    // 下書き保存のためのリクエストを送信
    try {
      const response = await fetch(form.action, {
        method: 'PATCH',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content,
          'Accept': 'application/json'
          // Content-Type は fetch が自動的に multipart/form-data に設定してくれる
        }
      })

      if (response.ok) {
        // 保存成功
        console.log("Thumbnail saved successfully")
        return true
      } else {
        const errorText = await response.text()
        console.error("Save error response:", errorText)
        alert("画像のアップロードに失敗しました。もう一度お試しください。")
        return false
      }
    } catch (error) {
      console.error("Draft save error:", error)
      alert("画像のアップロードに失敗しました。もう一度お試しください。")
      return false
    }
  }

  submitPublish(url) {
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
