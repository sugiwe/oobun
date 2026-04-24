import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "content",              // 本文コンテンツエリア（markdown/plain）
    "paragraphButton",      // 段落ホバー時の付箋追加ボタン
    "modal",                // 付箋作成モーダル
    "form",                 // 付箋作成フォーム
    "paragraphPreview",     // 段落プレビュー
    "bodyInput",            // 付箋の内容入力欄
    "visibilityRadios",     // 公開設定ラジオボタン
    "errorMessage"          // エラーメッセージ表示エリア
  ]

  static values = {
    threadSlug: String,
    postId: String,
    currentUserId: Number,
    annotations: Array
  }

  connect() {
    console.log("Annotation controller connected (paragraph-level)")
    console.log("Annotations:", this.annotationsValue)

    // Markdown表示の<p>タグに段落番号を付与
    this.setupParagraphsForMarkdown()

    // 段落アイコンを描画
    this.renderParagraphIcons()
  }

  disconnect() {
    // クリーンアップ
  }

  // Markdown表示の<p>タグに段落番号とホバーイベントを設定
  setupParagraphsForMarkdown() {
    this.contentTargets.forEach(contentTarget => {
      const isMarkdownView = contentTarget.classList.contains("markdown-body")

      if (isMarkdownView) {
        const paragraphs = contentTarget.querySelectorAll("p")
        paragraphs.forEach((p, index) => {
          p.dataset.paragraphIndex = index
          p.classList.add("paragraph", "relative", "px-2", "py-1", "rounded", "transition-colors")
          p.dataset.action = "mouseenter->annotation#showParagraphButton mouseleave->annotation#hideParagraphButton"
        })
      }
    })
  }

  // 段落ホバー時にボタンを表示
  showParagraphButton(event) {
    if (!this.hasParagraphButtonTarget) return
    if (this.currentUserIdValue === 0) return // 未ログイン

    const paragraph = event.currentTarget
    const rect = paragraph.getBoundingClientRect()

    // 段落を薄いグレー背景に
    paragraph.classList.add("bg-gray-50")

    // ボタンを段落の右上に配置
    this.paragraphButtonTarget.classList.remove("hidden")
    this.paragraphButtonTarget.style.top = `${rect.top + window.scrollY}px`
    this.paragraphButtonTarget.style.right = `${window.innerWidth - rect.right + window.scrollX + 8}px`

    // ボタンに段落情報を保存
    this.paragraphButtonTarget.dataset.paragraphIndex = paragraph.dataset.paragraphIndex
    this.paragraphButtonTarget.dataset.paragraphElement = paragraph
  }

  // 段落ホバー解除時にボタンを非表示
  hideParagraphButton(event) {
    const paragraph = event.currentTarget
    paragraph.classList.remove("bg-gray-50")

    // ボタンにマウスが移動していない場合のみ非表示
    setTimeout(() => {
      if (!this.hasParagraphButtonTarget) return
      const buttonRect = this.paragraphButtonTarget.getBoundingClientRect()
      const mouseX = event.clientX
      const mouseY = event.clientY

      const isOverButton = (
        mouseX >= buttonRect.left &&
        mouseX <= buttonRect.right &&
        mouseY >= buttonRect.top &&
        mouseY <= buttonRect.bottom
      )

      if (!isOverButton) {
        this.paragraphButtonTarget.classList.add("hidden")
      }
    }, 100)
  }

  // 段落用のモーダルを開く
  openModalForParagraph(event) {
    const paragraphIndex = parseInt(event.currentTarget.dataset.paragraphIndex)
    const paragraphElement = this.getParagraphElement(paragraphIndex)

    if (!paragraphElement) {
      console.error("Paragraph not found:", paragraphIndex)
      return
    }

    // 段落の全文を取得
    const paragraphText = paragraphElement.textContent.trim()

    // 既に付箋があるかチェック
    const existingAnnotation = this.annotationsValue.find(a =>
      a.paragraph_index === paragraphIndex && a.user_id === this.currentUserIdValue
    )

    if (existingAnnotation) {
      this.showError("この段落には既に付箋を追加しています")
      return
    }

    // モーダルに段落情報を保存
    this.currentParagraphIndex = paragraphIndex
    this.currentParagraphText = paragraphText

    // プレビューに段落の冒頭を表示
    const previewText = paragraphText.length > 200
      ? paragraphText.slice(0, 200) + "..."
      : paragraphText

    if (this.hasParagraphPreviewTarget) {
      this.paragraphPreviewTarget.textContent = previewText
    }

    // フォームをリセット
    if (this.hasFormTarget) {
      this.formTarget.reset()
    }
    this.clearError()

    // モーダルを表示
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
    }

    // ボタンを非表示
    if (this.hasParagraphButtonTarget) {
      this.paragraphButtonTarget.classList.add("hidden")
    }
  }

  // モーダルを閉じる
  closeModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
    }
    this.currentParagraphIndex = null
    this.currentParagraphText = null
    this.clearError()
  }

  // フォーム送信（付箋作成）
  async submitForm(event) {
    event.preventDefault()
    this.clearError()

    if (!this.currentParagraphIndex && this.currentParagraphIndex !== 0) {
      this.showError("段落が選択されていません")
      return
    }

    const formData = new FormData(this.formTarget)
    formData.append("annotation[paragraph_index]", this.currentParagraphIndex)
    formData.append("annotation[selected_text]", this.currentParagraphText.slice(0, 300)) // 冒頭300文字
    formData.append("annotation[start_offset]", 0) // 後方互換性のため
    formData.append("annotation[end_offset]", this.currentParagraphText.length)

    try {
      const response = await fetch(
        `/${this.threadSlugValue}/posts/${this.postIdValue}/annotations`,
        {
          method: "POST",
          headers: {
            "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
            "Accept": "application/json"
          },
          body: formData
        }
      )

      const data = await response.json()

      if (response.ok && data.success) {
        // 成功: annotationsValueに追加
        this.annotationsValue = [...this.annotationsValue, data.annotation]

        // モーダルを閉じる
        this.closeModal()

        // 成功トーストを表示
        this.showSuccessToast(data.message || "付箋を追加しました")

        // 段落アイコンを再描画
        this.renderParagraphIcons()
      } else {
        this.showError(data.errors?.join(", ") || "付箋の追加に失敗しました")
      }
    } catch (error) {
      console.error("Failed to create annotation:", error)
      this.showError("通信エラーが発生しました")
    }
  }

  // エラーメッセージを表示
  showError(message) {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
      this.errorMessageTarget.classList.remove("hidden")
    }
  }

  // エラーメッセージをクリア
  clearError() {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = ""
      this.errorMessageTarget.classList.add("hidden")
    }
  }

  // 成功トーストを表示
  showSuccessToast(message) {
    const toast = document.createElement("div")
    toast.className = "fixed top-4 right-4 z-50 bg-green-500 text-white px-6 py-3 rounded-lg shadow-lg flex items-center gap-2"
    toast.innerHTML = `
      <span class="text-lg">✅</span>
      <span class="text-sm font-medium">${message}</span>
    `

    document.body.appendChild(toast)

    setTimeout(() => {
      toast.classList.add("opacity-0", "transition-opacity", "duration-300")
      setTimeout(() => {
        if (toast.parentElement) {
          document.body.removeChild(toast)
        }
      }, 300)
    }, 2500)
  }

  // 段落要素を取得
  getParagraphElement(paragraphIndex) {
    let paragraphElement = null

    this.contentTargets.forEach(contentTarget => {
      if (paragraphElement) return // 既に見つかっている

      const candidate = contentTarget.querySelector(`[data-paragraph-index="${paragraphIndex}"]`)
      if (candidate) {
        paragraphElement = candidate
      }
    })

    return paragraphElement
  }

  // 段落アイコンを描画（既存の付箋を表示）
  renderParagraphIcons() {
    if (!this.annotationsValue || this.annotationsValue.length === 0) {
      return
    }

    // 既存のアイコンをクリア
    document.querySelectorAll("[data-annotation-icon]").forEach(icon => icon.remove())

    // 段落ごとにアイコンを追加
    this.annotationsValue.forEach(annotation => {
      if (annotation.paragraph_index === null || annotation.paragraph_index === undefined) {
        return // 文字単位の古い付箋はスキップ
      }

      const paragraphElement = this.getParagraphElement(annotation.paragraph_index)
      if (!paragraphElement) {
        console.warn("Paragraph not found for annotation:", annotation)
        return
      }

      // アイコンを作成
      const icon = document.createElement("span")
      icon.className = "inline-flex items-center justify-center w-6 h-6 text-sm cursor-pointer hover:scale-110 transition-transform ml-1"
      icon.textContent = annotation.icon
      icon.dataset.annotationIcon = ""
      icon.dataset.annotationId = annotation.id
      icon.dataset.action = "click->annotation#showAnnotationPopover"

      // 段落の末尾に追加
      paragraphElement.appendChild(icon)
    })
  }

  // 付箋アイコンクリック時にポップオーバーを表示
  showAnnotationPopover(event) {
    event.preventDefault()
    event.stopPropagation()

    const annotationId = parseInt(event.currentTarget.dataset.annotationId)
    const annotation = this.annotationsValue.find(a => a.id === annotationId)

    if (!annotation) {
      console.error("Annotation not found:", annotationId)
      return
    }

    // 既存のポップオーバーを削除
    this.hideAnnotationPopover()

    // ポップオーバー要素を作成
    const popover = document.createElement("div")
    popover.className = "fixed z-50 bg-white border border-gray-300 rounded-lg shadow-xl max-w-md p-4"
    popover.dataset.annotationPopover = ""

    popover.innerHTML = `
      <div class="flex items-start justify-between gap-3 mb-2">
        <div class="flex items-center gap-2">
          <span class="text-lg">${annotation.icon}</span>
          <span class="text-sm font-medium text-gray-900">${this.escapeHtml(annotation.user.display_name)}</span>
        </div>
        <button class="text-gray-400 hover:text-gray-600" data-close-popover>✕</button>
      </div>
      <div class="text-xs text-gray-500 mb-2">この段落について:</div>
      <blockquote class="bg-gray-50 border-l-4 border-gray-300 pl-2 py-1 text-sm text-gray-700 italic mb-3 max-h-24 overflow-y-auto">
        ${this.escapeHtml(annotation.selected_text)}
      </blockquote>
      <div class="text-xs text-gray-500 mb-1">メモ:</div>
      <div class="text-sm text-gray-800 whitespace-pre-wrap">
        ${this.escapeHtml(annotation.body)}
      </div>
    `

    // 位置を計算（クリックされたアイコンの下）
    const rect = event.currentTarget.getBoundingClientRect()
    const top = rect.bottom + window.scrollY + 8
    const left = rect.left + window.scrollX

    popover.style.top = `${top}px`
    popover.style.left = `${left}px`

    // DOMに追加
    document.body.appendChild(popover)

    // 閉じるボタンにイベントリスナーを追加
    const closeButton = popover.querySelector("[data-close-popover]")
    closeButton.addEventListener("click", () => {
      this.hideAnnotationPopover()
    })

    // 外部クリックで閉じる
    setTimeout(() => {
      document.addEventListener("click", this.closePopoverOnOutsideClick.bind(this), { once: true })
    }, 0)
  }

  // ポップオーバーを非表示
  hideAnnotationPopover() {
    const existing = document.querySelector("[data-annotation-popover]")
    if (existing) {
      existing.remove()
    }
  }

  // 外部クリックでポップオーバーを閉じる
  closePopoverOnOutsideClick(event) {
    const clickedInsidePopover = event.target.closest("[data-annotation-popover]")
    if (!clickedInsidePopover) {
      this.hideAnnotationPopover()
    }
  }

  // HTMLエスケープ
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  // 公開設定変更時のフォーム背景色変更
  updateFormBackground(event) {
    const selectedValue = event.target.value
    const bodyInput = this.bodyInputTarget

    if (selectedValue === "self_only") {
      bodyInput.classList.remove("bg-yellow-50")
      bodyInput.classList.add("bg-blue-50")
    } else if (selectedValue === "public_visible") {
      bodyInput.classList.remove("bg-blue-50")
      bodyInput.classList.add("bg-yellow-50")
    }
  }
}
