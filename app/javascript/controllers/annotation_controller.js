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
    // Markdown表示の<p>タグに段落番号を付与
    this.setupParagraphsForMarkdown()

    // Plain表示の段落にもボタンを追加
    this.setupParagraphsForPlain()

    // 段落アイコンを描画
    this.renderParagraphIcons()

    // 表示モード切り替え時にアイコンを再描画
    this.element.addEventListener("view-mode-changed", () => {
      this.renderParagraphIcons()
    })
  }

  disconnect() {
    // クリーンアップ
  }

  // Markdown表示のブロック要素に段落番号とホバーイベントを設定
  setupParagraphsForMarkdown() {
    this.contentTargets.forEach(contentTarget => {
      const isMarkdownView = contentTarget.classList.contains("markdown-body")

      if (isMarkdownView) {
        // ブロック要素全般を対象にする（段落、見出し、リスト全体、引用、コードブロック）
        // ul/olは最上位のもののみ対象（ネストした子ul/olは除外）
        const blocks = contentTarget.querySelectorAll("p, h1, h2, h3, h4, h5, h6, ul:not(ul ul):not(ol ul), ol:not(ul ol):not(ol ol), blockquote, pre")
        blocks.forEach((block, index) => {
          block.dataset.paragraphIndex = index
          block.classList.add("paragraph", "relative", "px-2", "py-1", "rounded", "transition-colors")
          block.dataset.action = "mouseenter->annotation#showParagraphButton mouseleave->annotation#hideParagraphButton"

          // 付箋追加ボタンを段落内に作成（ログイン時のみ）
          if (this.currentUserIdValue !== 0) {
            this.createParagraphButton(block)
          }

          // アイコンコンテナを段落の下に追加
          const iconsContainer = document.createElement("div")
          iconsContainer.className = "flex items-center gap-1 mt-1"
          iconsContainer.dataset.annotationIconsContainer = ""
          block.appendChild(iconsContainer)
        })
      }
    })
  }

  // Plain表示の段落設定（付箋機能は無効）
  setupParagraphsForPlain() {
    // Plain表示では付箋機能を提供しない
    // （Markdownの構造を正確に把握できないため、段落番号が一致しない）
  }

  // 段落内に付箋追加ボタンを作成
  createParagraphButton(paragraph) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "absolute top-1 right-1 bg-gray-900 text-white text-xs px-3 py-2 rounded shadow-lg hover:bg-gray-700 transition-colors opacity-0 hover:opacity-100"
    button.textContent = "📌 付箋を追加"
    button.dataset.paragraphButton = ""
    button.dataset.action = "click->annotation#openModalForParagraph"
    paragraph.appendChild(button)
  }

  // 段落ホバー時にボタンを表示
  showParagraphButton(event) {
    if (this.currentUserIdValue === 0) return // 未ログイン

    const paragraph = event.currentTarget
    const button = paragraph.querySelector("[data-paragraph-button]")

    if (button) {
      // 段落を薄いグレー背景に
      paragraph.classList.add("bg-gray-50")
      // ボタンを表示
      button.classList.remove("opacity-0")
      button.classList.add("opacity-100")
    }
  }

  // 段落ホバー解除時にボタンを非表示
  hideParagraphButton(event) {
    const paragraph = event.currentTarget
    const button = paragraph.querySelector("[data-paragraph-button]")

    if (button) {
      // 背景を戻す
      paragraph.classList.remove("bg-gray-50")
      // ボタンを非表示
      button.classList.remove("opacity-100")
      button.classList.add("opacity-0")
    }
  }

  // 段落用のモーダルを開く
  openModalForParagraph(event) {
    // ボタンの親要素（段落）から段落番号を取得
    const paragraph = event.currentTarget.closest(".paragraph")
    const paragraphIndex = parseInt(paragraph.dataset.paragraphIndex)

    if (!paragraph) {
      console.error("Paragraph not found")
      return
    }

    // 段落の全文を取得（ボタンとアイコンコンテナを除外）
    const button = paragraph.querySelector("[data-paragraph-button]")
    const iconsContainer = paragraph.querySelector("[data-annotation-icons-container]")
    const clone = paragraph.cloneNode(true)
    clone.querySelector("[data-paragraph-button]")?.remove()
    clone.querySelector("[data-annotation-icons-container]")?.remove()
    const paragraphText = clone.textContent.trim()

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

  // 段落要素を取得（現在表示されているコンテンツエリアから）
  getParagraphElement(paragraphIndex) {
    let paragraphElement = null

    this.contentTargets.forEach(contentTarget => {
      if (paragraphElement) return // 既に見つかっている

      // hidden クラスがついている（非表示の）コンテンツエリアはスキップ
      if (contentTarget.classList.contains("hidden")) {
        return
      }

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

    // Plain表示の場合は付箋を描画しない
    const isPlainView = this.contentTargets.some(target =>
      !target.classList.contains("hidden") && !target.classList.contains("markdown-body")
    )
    if (isPlainView) {
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
        return
      }

      // アイコンコンテナを取得（なければ段落の末尾に作成）
      let iconsContainer = paragraphElement.querySelector('[data-annotation-icons-container]')
      if (!iconsContainer) {
        iconsContainer = document.createElement("span")
        iconsContainer.className = "flex items-center gap-1 shrink-0"
        iconsContainer.dataset.annotationIconsContainer = ""
        paragraphElement.appendChild(iconsContainer)
      }

      // アイコンを作成
      const icon = document.createElement("span")
      icon.className = "inline-flex items-center justify-center w-6 h-6 shrink-0 cursor-pointer hover:scale-110 transition-transform"
      icon.dataset.annotationIcon = ""
      icon.dataset.annotationId = annotation.id
      icon.dataset.action = "click->annotation#showAnnotationPopover"

      // 公開付箋の場合はアバター画像、自分用の場合は🔒
      const avatarUrl = annotation.user_avatar_url || annotation.user?.avatar_url
      const displayName = annotation.user_display_name || annotation.user?.display_name

      if (annotation.visibility === "public_visible" && avatarUrl) {
        // アバター画像を表示
        icon.className += " rounded-full overflow-hidden border border-gray-300"
        const avatar = document.createElement("img")
        avatar.src = avatarUrl
        avatar.alt = displayName
        avatar.className = "w-full h-full object-cover"
        avatar.style.cssText = "margin: 0 !important; border-radius: 0 !important; height: 100% !important;"
        icon.appendChild(avatar)
      } else if (annotation.visibility === "public_visible") {
        // アバターがない場合はイニシャル
        icon.className += " bg-gray-200 rounded-full text-xs text-gray-600"
        icon.textContent = displayName ? displayName[0] : "?"
      } else {
        // 自分用付箋は🔒
        icon.className += " text-sm"
        icon.textContent = "🔒"
      }

      // アイコンコンテナに追加
      iconsContainer.appendChild(icon)
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

    // クリックされたアイコンへの参照を保持（スクロール時の位置更新用）
    this.currentPopoverIcon = event.currentTarget

    // ポップオーバー要素を作成
    const popover = document.createElement("div")
    // 公開付箋は薄黄色、自分用は薄青色の背景
    const bgColor = annotation.visibility === "public_visible" ? "bg-yellow-50" : "bg-blue-50"
    popover.className = `fixed z-50 ${bgColor} p-4`
    popover.style.cssText = "width: 288px; border-radius: 2px; box-shadow: 3px 3px 6px rgba(0, 0, 0, 0.15), 1px 1px 2px rgba(0, 0, 0, 0.1);"
    popover.dataset.annotationPopover = ""

    const displayName = annotation.user_display_name || annotation.user?.display_name || "Unknown"
    const avatarUrl = annotation.user_avatar_url || annotation.user?.avatar_url

    popover.innerHTML = `<div class="flex items-start justify-between gap-3 mb-3"><div class="flex items-center gap-2"><span class="text-lg">${annotation.icon}</span><span class="text-sm font-medium text-gray-900">${this.escapeHtml(displayName)}</span></div><button class="text-gray-400 hover:text-gray-600" data-close-popover>✕</button></div><div class="text-sm text-gray-800 whitespace-pre-wrap" style="line-height: 1.75;">${this.escapeHtml(annotation.body)}</div>`

    // 位置を計算（クリックされたアイコンの下）
    // position: fixed を使うので、scrollY/scrollX は不要（viewport基準）
    this.updatePopoverPosition(popover)

    // DOMに追加
    document.body.appendChild(popover)

    // スクロール時に位置を更新
    this.scrollHandler = () => this.updatePopoverPosition(popover)
    window.addEventListener("scroll", this.scrollHandler, { passive: true })

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

  // ポップオーバーの位置を更新
  updatePopoverPosition(popover) {
    if (!this.currentPopoverIcon || !popover) return

    const rect = this.currentPopoverIcon.getBoundingClientRect()
    const top = rect.bottom + 8  // アイコンの下に8px空ける
    const left = rect.left

    popover.style.top = `${top}px`
    popover.style.left = `${left}px`
  }

  // ポップオーバーを非表示
  hideAnnotationPopover() {
    const existing = document.querySelector("[data-annotation-popover]")
    if (existing) {
      existing.remove()
    }

    // スクロールイベントリスナーを削除
    if (this.scrollHandler) {
      window.removeEventListener("scroll", this.scrollHandler)
      this.scrollHandler = null
    }

    // アイコンへの参照をクリア
    this.currentPopoverIcon = null
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
