import { Controller } from "@hotwired/stimulus"

// マーカー・付箋機能のコントローラー
export default class extends Controller {
  static targets = [
    "content",           // 投稿本文エリア
    "tooltip",           // テキスト選択時のツールチップ
    "modal",             // マーカー作成・編集モーダル
    "form",              // フォーム
    "visibilityRadios",  // 可視性ラジオボタン
    "bodyInput",         // 付箋本文の入力欄
    "selectedTextPreview", // 選択したテキストのプレビュー
    "errorMessage",      // エラーメッセージ表示エリア
    "viewSelector"       // マーカービュー切り替えセレクター
  ]

  static values = {
    threadSlug: String,
    postId: String,
    currentUserId: Number,
    annotations: Array
  }

  connect() {
    console.log("Annotation controller connected")
    console.log("Annotations:", this.annotationsValue)

    // 複数のcontentTargetがある場合に対応（markdown/plain）
    this.contentTargets.forEach(target => {
      target.addEventListener("mouseup", this.handleTextSelection.bind(this))
      target.addEventListener("touchend", this.handleTextSelection.bind(this))
    })

    // ドキュメント全体のクリックでツールチップを閉じる
    document.addEventListener("click", this.hideTooltipOnOutsideClick.bind(this))

    // マーカーを描画
    this.renderMarkers()
  }

  disconnect() {
    this.contentTargets.forEach(target => {
      target.removeEventListener("mouseup", this.handleTextSelection.bind(this))
      target.removeEventListener("touchend", this.handleTextSelection.bind(this))
    })
    document.removeEventListener("click", this.hideTooltipOnOutsideClick.bind(this))
  }

  // テキスト選択時の処理
  handleTextSelection(event) {
    const selection = window.getSelection()
    const selectedText = selection.toString().trim()

    console.log("Text selected:", selectedText.substring(0, 50))

    if (selectedText.length === 0) {
      this.hideTooltip()
      return
    }

    // 選択範囲が300文字を超える場合は警告
    if (selectedText.length > 300) {
      alert("選択範囲は300文字以内にしてください")
      this.hideTooltip()
      return
    }

    // 段落を跨いでいないかチェック（\n\nが含まれていたらNG）
    if (selectedText.includes("\n\n")) {
      alert("段落を跨いだ選択はできません。1つの段落内で選択してください")
      this.hideTooltip()
      return
    }

    // 選択範囲の位置を取得してツールチップを表示
    const range = selection.getRangeAt(0)
    const rect = range.getBoundingClientRect()

    // どのcontentエリアで選択されたかを特定
    const containerElement = event.currentTarget

    this.showTooltip(rect, selectedText, range, containerElement)
  }

  // ツールチップを表示
  showTooltip(rect, selectedText, range, containerElement) {
    this.tooltipTarget.classList.remove("hidden")

    // ツールチップの位置を計算（選択範囲の上部中央）
    const tooltipWidth = this.tooltipTarget.offsetWidth
    const left = rect.left + (rect.width / 2) - (tooltipWidth / 2) + window.scrollX
    const top = rect.top - 40 + window.scrollY

    this.tooltipTarget.style.left = `${left}px`
    this.tooltipTarget.style.top = `${top}px`

    // 選択情報を保存
    this.currentSelection = {
      text: selectedText,
      range: range,
      containerElement: containerElement,
      startOffset: this.getTextOffset(range.startContainer, range.startOffset, containerElement),
      endOffset: this.getTextOffset(range.endContainer, range.endOffset, containerElement)
    }
  }

  // ツールチップを非表示
  hideTooltip() {
    if (this.hasTooltipTarget) {
      this.tooltipTarget.classList.add("hidden")
    }
    this.currentSelection = null
  }

  // 外部クリックでツールチップとポップオーバーを閉じる
  hideTooltipOnOutsideClick(event) {
    // ツールチップ、モーダル、コンテンツエリア、ポップオーバー内のクリックは無視
    const clickedInsideContent = this.contentTargets.some(target => target.contains(event.target))
    const clickedInsideModal = this.hasModalTarget && this.modalTarget.contains(event.target)
    const clickedInsidePopover = event.target.closest("[data-annotation-popover]")
    const clickedInsideTooltip = this.hasTooltipTarget && this.tooltipTarget.contains(event.target)

    if (clickedInsideTooltip || clickedInsideContent || clickedInsideModal || clickedInsidePopover) {
      return
    }

    // ツールチップとポップオーバーを閉じる
    if (this.hasTooltipTarget) {
      this.hideTooltip()
    }
    this.hideAnnotationPopover()
  }

  // テキストオフセット位置を計算（Postのbody全体からの文字位置）
  getTextOffset(node, offset, containerElement) {
    // containerElement内の全テキストを取得
    const fullText = containerElement.textContent

    // nodeまでのテキストを取得
    const range = document.createRange()
    range.selectNodeContents(containerElement)
    range.setEnd(node, offset)

    return range.toString().length
  }

  // 「この箇所にマーカー」ボタンクリック
  openModal(event) {
    event.preventDefault()
    event.stopPropagation()

    console.log("openModal called, currentSelection:", this.currentSelection)

    if (!this.currentSelection) {
      alert("テキストを選択してください")
      return
    }

    // モーダルを表示
    this.modalTarget.classList.remove("hidden")

    // 選択されたテキストをプレビュー表示
    this.selectedTextPreviewTarget.textContent = this.currentSelection.text

    // フォームをリセット
    this.formTarget.reset()
    this.bodyInputTarget.value = ""
    this.updateFormBackground()

    // 付箋本文にフォーカス
    this.bodyInputTarget.focus()

    // ツールチップを非表示（currentSelectionは保持）
    if (this.hasTooltipTarget) {
      this.tooltipTarget.classList.add("hidden")
    }
  }

  // モーダルを閉じる
  closeModal(event) {
    if (event) {
      event.preventDefault()
    }

    this.modalTarget.classList.add("hidden")
    this.clearError()

    // 選択を解除
    window.getSelection().removeAllRanges()
  }

  // 可視性変更時にフォームの背景色を変える
  updateFormBackground() {
    const selectedVisibility = this.visibilityRadiosTargets.find(radio => radio.checked)?.value

    if (selectedVisibility === "self_only") {
      this.bodyInputTarget.classList.remove("bg-yellow-50")
      this.bodyInputTarget.classList.add("bg-blue-50")
    } else if (selectedVisibility === "public_visible") {
      this.bodyInputTarget.classList.remove("bg-blue-50")
      this.bodyInputTarget.classList.add("bg-yellow-50")
    }
  }

  // フォーム送信
  async submitForm(event) {
    event.preventDefault()

    console.log("submitForm called, currentSelection:", this.currentSelection)

    if (!this.currentSelection) {
      this.showError("選択範囲が見つかりません")
      return
    }

    console.log("startOffset:", this.currentSelection.startOffset)
    console.log("endOffset:", this.currentSelection.endOffset)
    console.log("selected text:", this.currentSelection.text)

    // 自分の既存のマーカーと重複チェック（他の人のマーカーは除外）
    const hasOverlap = this.annotationsValue.some(annotation => {
      // 他の人のマーカーはスキップ
      if (annotation.user_id !== this.currentUserIdValue) {
        return false
      }

      const existingStart = annotation.start_offset
      const existingEnd = annotation.end_offset
      const newStart = this.currentSelection.startOffset
      const newEnd = this.currentSelection.endOffset

      // 重複判定: 新しいマーカーの開始が既存の範囲内、または終了が既存の範囲内
      return (newStart < existingEnd && newEnd > existingStart)
    })

    if (hasOverlap) {
      this.showError("自分の既存のマーカーと重複しています。別の範囲を選択してください。")
      return
    }

    const formData = new FormData(this.formTarget)
    formData.append("annotation[start_offset]", this.currentSelection.startOffset)
    formData.append("annotation[end_offset]", this.currentSelection.endOffset)
    formData.append("annotation[selected_text]", this.currentSelection.text)

    try {
      const response = await fetch(
        `/${this.threadSlugValue}/posts/${this.postIdValue}/annotations`,
        {
          method: "POST",
          headers: {
            "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
            "Accept": "application/json"
          },
          body: formData
        }
      )

      const data = await response.json()

      console.log("Response data:", data)

      if (data.success) {
        // 成功: モーダルを閉じて成功メッセージを表示
        console.log("Success! Showing success message...")
        this.closeModal()
        this.showSuccessToast(data.message)

        // 2秒後にリロード
        setTimeout(() => {
          window.location.reload()
        }, 1500)
      } else {
        this.showError(data.errors.join(", "))
      }
    } catch (error) {
      console.error("Annotation creation failed:", error)
      this.showError("マーカー・付箋の追加に失敗しました")
    }
  }

  // エラーメッセージを表示
  showError(message) {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
      this.errorMessageTarget.classList.remove("hidden")
    } else {
      alert(message)
    }
  }

  // エラーメッセージをクリア
  clearError() {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = ""
      this.errorMessageTarget.classList.add("hidden")
    }
  }

  // マーカークリック時に付箋内容を表示
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
    popover.className = "fixed z-50 bg-white border border-gray-300 rounded-lg shadow-xl max-w-sm p-4"
    popover.dataset.annotationPopover = ""

    popover.innerHTML = `
      <div class="flex items-start justify-between gap-3 mb-2">
        <div class="flex items-center gap-2">
          <span class="text-lg">${annotation.icon}</span>
          <span class="text-sm font-medium text-gray-900">${annotation.user.display_name}</span>
        </div>
        <button class="text-gray-400 hover:text-gray-600" data-close-popover>✕</button>
      </div>
      <div class="text-xs text-gray-500 mb-2">選択箇所:</div>
      <blockquote class="bg-gray-50 border-l-4 border-gray-300 pl-2 py-1 text-sm text-gray-700 italic mb-3">
        ${this.escapeHtml(annotation.selected_text)}
      </blockquote>
      <div class="text-xs text-gray-500 mb-1">メモ:</div>
      <div class="text-sm text-gray-800 whitespace-pre-wrap">
        ${this.escapeHtml(annotation.body)}
      </div>
    `

    // 位置を計算（クリックされたマーカーの下）
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
  }

  // ポップオーバーを非表示
  hideAnnotationPopover() {
    const existing = document.querySelector("[data-annotation-popover]")
    if (existing) {
      existing.remove()
    }
  }

  // HTMLエスケープ
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  // 成功トーストを表示
  showSuccessToast(message) {
    // トースト要素を作成
    const toast = document.createElement("div")
    toast.className = "fixed top-4 right-4 z-50 bg-green-500 text-white px-6 py-3 rounded-lg shadow-lg flex items-center gap-2 animate-slide-in"
    toast.innerHTML = `
      <span class="text-lg">✅</span>
      <span class="text-sm font-medium">${message}</span>
    `

    // DOM に追加
    document.body.appendChild(toast)

    // 2.5秒後に自動削除
    setTimeout(() => {
      toast.classList.add("opacity-0", "transition-opacity", "duration-300")
      setTimeout(() => {
        document.body.removeChild(toast)
      }, 300)
    }, 2500)
  }

  // マーカーを描画
  renderMarkers() {
    if (!this.annotationsValue || this.annotationsValue.length === 0) {
      console.log("No annotations to render")
      return
    }

    // 各contentエリアにマーカーを適用
    this.contentTargets.forEach(contentTarget => {
      const isPlainView = contentTarget.classList.contains("whitespace-pre-wrap")

      if (isPlainView) {
        // Plain表示の場合のみマーカーを適用
        this.applyMarkersToPlainText(contentTarget)
      }
      // Markdown表示の場合は、HTML構造が複雑なため一旦スキップ
      // TODO: Markdown表示でもマーカーを適用する
    })
  }

  // Plainテキストにマーカーを適用
  applyMarkersToPlainText(contentElement) {
    // 初回のみ、元のプレーンテキストを保存
    if (!contentElement.dataset.originalText) {
      contentElement.dataset.originalText = contentElement.textContent
    }

    const originalText = contentElement.dataset.originalText

    // annotationsをstart_offsetでソート（逆順：後ろから適用）
    const sortedAnnotations = [...this.annotationsValue].sort((a, b) => b.start_offset - a.start_offset)

    let markedHTML = originalText

    // 後ろから順にマーカーを挿入（文字位置がずれないようにするため）
    sortedAnnotations.forEach(annotation => {
      const before = markedHTML.slice(0, annotation.start_offset)
      const marked = markedHTML.slice(annotation.start_offset, annotation.end_offset)
      const after = markedHTML.slice(annotation.end_offset)

      // マーカー要素を作成
      const markerHTML = `<mark class="${annotation.marker_color_class} cursor-pointer px-1 rounded" data-annotation-id="${annotation.id}" data-action="click->annotation#showAnnotationPopover">${marked}</mark>`

      markedHTML = before + markerHTML + after
    })

    // HTMLとして適用
    contentElement.innerHTML = markedHTML.replace(/\n/g, "<br>")
  }

  // マーカービュー切り替え
  changeView(event) {
    const selectedUserId = event.target.value

    // すべてのマーカーを一旦非表示
    const allMarkers = this.element.querySelectorAll("[data-annotation-user-id]")
    allMarkers.forEach(marker => {
      marker.classList.add("hidden")
    })

    // 選択されたユーザーのマーカーを表示
    if (selectedUserId === "all") {
      // 公開マーカーのみ表示
      const publicMarkers = this.element.querySelectorAll("[data-annotation-visibility='public']")
      publicMarkers.forEach(marker => {
        marker.classList.remove("hidden")
      })
    } else if (selectedUserId === "mine") {
      // 自分のマーカー（公開 + 自分用）を表示
      const myMarkers = this.element.querySelectorAll(`[data-annotation-user-id='${this.currentUserIdValue}']`)
      myMarkers.forEach(marker => {
        marker.classList.remove("hidden")
      })
    } else {
      // 特定ユーザーの公開マーカーのみ表示
      const userMarkers = this.element.querySelectorAll(
        `[data-annotation-user-id='${selectedUserId}'][data-annotation-visibility='public']`
      )
      userMarkers.forEach(marker => {
        marker.classList.remove("hidden")
      })
    }
  }
}
