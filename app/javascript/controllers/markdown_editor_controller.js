import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "editTab", "previewTab", "editArea", "previewArea", "preview", "textarea",
    "linkModal", "linkUrlInput", "embedModal", "embedUrlInput"
  ]

  connect() {
    this.previewEndpoint = "/preview_markdown"
    this.ogpEndpoint = "/fetch_ogp"
    this.debounceTimer = null

    // 初期表示時にテキストエリアの高さを調整
    this.adjustTextareaHeight()
  }

  // テキストエリアの高さを自動調整
  adjustTextareaHeight() {
    const textarea = this.textareaTarget

    // 一旦高さをリセットして、scrollHeightを正確に取得
    textarea.style.height = 'auto'

    // 最小高さ（14行分、約336px）を確保しつつ、内容に応じて拡大
    const minHeight = 336 // rows: 14 の場合の高さ
    const newHeight = Math.max(minHeight, textarea.scrollHeight)

    textarea.style.height = newHeight + 'px'
  }

  showEdit(event) {
    event.preventDefault()

    // タブのスタイル切り替え
    this.editTabTarget.classList.add("border-gray-900", "text-gray-900")
    this.editTabTarget.classList.remove("border-transparent", "text-gray-500")
    this.previewTabTarget.classList.add("border-transparent", "text-gray-500")
    this.previewTabTarget.classList.remove("border-gray-900", "text-gray-900")

    // エリアの表示切り替え
    this.editAreaTarget.classList.remove("hidden")
    this.previewAreaTarget.classList.add("hidden")
  }

  showPreview(event) {
    event.preventDefault()

    // タブのスタイル切り替え
    this.previewTabTarget.classList.add("border-gray-900", "text-gray-900")
    this.previewTabTarget.classList.remove("border-transparent", "text-gray-500")
    this.editTabTarget.classList.add("border-transparent", "text-gray-500")
    this.editTabTarget.classList.remove("border-gray-900", "text-gray-900")

    // エリアの表示切り替え
    this.previewAreaTarget.classList.remove("hidden")
    this.editAreaTarget.classList.add("hidden")

    // プレビューを更新
    this.updatePreview()
  }

  async updatePreview() {
    const text = this.textareaTarget.value

    if (!text || text.trim() === "") {
      this.previewTarget.innerHTML = '<div class="text-gray-400 text-sm">プレビューする内容がありません</div>'
      return
    }

    try {
      this.previewTarget.innerHTML = '<div class="text-gray-400 text-sm">プレビューを読み込み中...</div>'

      const response = await fetch(this.previewEndpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ text: text })
      })

      if (!response.ok) {
        throw new Error("プレビューの読み込みに失敗しました")
      }

      const data = await response.json()
      this.previewTarget.innerHTML = data.html
    } catch (error) {
      console.error("プレビューエラー:", error)
      this.previewTarget.innerHTML = '<div class="text-red-500 text-sm">プレビューの読み込みに失敗しました</div>'
    }
  }

  updateCharCount() {
    // テキストエリアの高さを自動調整
    this.adjustTextareaHeight()
  }

  // リンクモーダルを開く
  openLinkModal(event) {
    event.preventDefault()
    this.linkUrlInputTarget.value = ""
    this.linkModalTarget.classList.remove("hidden")
  }

  // リンクモーダルを閉じる
  closeLinkModal(event) {
    event.preventDefault()
    this.linkModalTarget.classList.add("hidden")
  }

  // 埋め込みモーダルを開く
  openEmbedModal(event) {
    event.preventDefault()
    this.embedUrlInputTarget.value = ""
    this.embedModalTarget.classList.remove("hidden")
  }

  // 埋め込みモーダルを閉じる
  closeEmbedModal(event) {
    event.preventDefault()
    this.embedModalTarget.classList.add("hidden")
  }

  // そのままリンクを挿入
  insertPlainLink(event) {
    event.preventDefault()
    const url = this.linkUrlInputTarget.value.trim()
    if (!url) {
      alert("URLを入力してください")
      return
    }
    this.insertTextAtCursor(url)
    this.closeLinkModal(event)
  }

  // マークダウンリンクを挿入（OGPでタイトル取得）
  async insertMarkdownLink(event) {
    event.preventDefault()
    const url = this.linkUrlInputTarget.value.trim()
    if (!url) {
      alert("URLを入力してください")
      return
    }

    try {
      const response = await fetch(this.ogpEndpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ url: url })
      })

      if (!response.ok) {
        throw new Error("OGP取得に失敗しました")
      }

      const data = await response.json()
      const title = data.title || url
      this.insertTextAtCursor(`[${title}](${url})`)
      this.closeLinkModal(event)
    } catch (error) {
      console.error("OGP取得エラー:", error)
      // エラー時はURLをそのまま使用
      this.insertTextAtCursor(`[${url}](${url})`)
      this.closeLinkModal(event)
    }
  }

  // OGPカードを挿入
  insertLinkCard(event) {
    event.preventDefault()
    const url = this.linkUrlInputTarget.value.trim()
    if (!url) {
      alert("URLを入力してください")
      return
    }
    this.insertTextAtCursor(`:::link-card ${url}\n`)
    this.closeLinkModal(event)
  }

  // YouTube埋め込みを挿入
  insertYouTubeEmbed(event) {
    event.preventDefault()
    const url = this.embedUrlInputTarget.value.trim()
    if (!url) {
      alert("URLを入力してください")
      return
    }
    this.insertTextAtCursor(`:::embed-youtube ${url}\n`)
    this.closeEmbedModal(event)
  }

  // Spotify埋め込みを挿入
  insertSpotifyEmbed(event) {
    event.preventDefault()
    const url = this.embedUrlInputTarget.value.trim()
    if (!url) {
      alert("URLを入力してください")
      return
    }
    this.insertTextAtCursor(`:::embed-spotify ${url}\n`)
    this.closeEmbedModal(event)
  }

  // X埋め込みを挿入
  insertXEmbed(event) {
    event.preventDefault()
    const url = this.embedUrlInputTarget.value.trim()
    if (!url) {
      alert("URLを入力してください")
      return
    }
    this.insertTextAtCursor(`:::embed-x ${url}\n`)
    this.closeEmbedModal(event)
  }

  // Instagram埋め込みを挿入
  insertInstagramEmbed(event) {
    event.preventDefault()
    const url = this.embedUrlInputTarget.value.trim()
    if (!url) {
      alert("URLを入力してください")
      return
    }
    this.insertTextAtCursor(`:::embed-instagram ${url}\n`)
    this.closeEmbedModal(event)
  }

  // カーソル位置にテキストを挿入
  insertTextAtCursor(text) {
    const textarea = this.textareaTarget
    const start = textarea.selectionStart
    const end = textarea.selectionEnd
    const before = textarea.value.substring(0, start)
    const after = textarea.value.substring(end)

    textarea.value = before + text + after
    textarea.selectionStart = textarea.selectionEnd = start + text.length
    textarea.focus()

    // 高さを調整
    this.adjustTextareaHeight()

    // draft-autosaveのinputイベントをトリガー
    textarea.dispatchEvent(new Event('input', { bubbles: true }))
  }
}
