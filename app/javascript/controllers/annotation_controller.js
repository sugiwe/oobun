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
    currentUserId: Number
  }

  connect() {
    // テキスト選択イベントをリッスン
    this.contentTarget.addEventListener("mouseup", this.handleTextSelection.bind(this))
    this.contentTarget.addEventListener("touchend", this.handleTextSelection.bind(this))

    // ドキュメント全体のクリックでツールチップを閉じる
    document.addEventListener("click", this.hideTooltipOnOutsideClick.bind(this))
  }

  disconnect() {
    this.contentTarget.removeEventListener("mouseup", this.handleTextSelection.bind(this))
    this.contentTarget.removeEventListener("touchend", this.handleTextSelection.bind(this))
    document.removeEventListener("click", this.hideTooltipOnOutsideClick.bind(this))
  }

  // テキスト選択時の処理
  handleTextSelection(event) {
    const selection = window.getSelection()
    const selectedText = selection.toString().trim()

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

    this.showTooltip(rect, selectedText, range)
  }

  // ツールチップを表示
  showTooltip(rect, selectedText, range) {
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
      startOffset: this.getTextOffset(range.startContainer, range.startOffset),
      endOffset: this.getTextOffset(range.endContainer, range.endOffset)
    }
  }

  // ツールチップを非表示
  hideTooltip() {
    if (this.hasTooltipTarget) {
      this.tooltipTarget.classList.add("hidden")
    }
    this.currentSelection = null
  }

  // 外部クリックでツールチップを閉じる
  hideTooltipOnOutsideClick(event) {
    if (!this.hasTooltipTarget) return

    // ツールチップ自体、またはコンテンツエリア内のクリックは無視
    if (this.tooltipTarget.contains(event.target) ||
        this.contentTarget.contains(event.target)) {
      return
    }

    this.hideTooltip()
  }

  // テキストオフセット位置を計算（Postのbody全体からの文字位置）
  getTextOffset(node, offset) {
    // contentTarget内の全テキストを取得
    const fullText = this.contentTarget.textContent

    // nodeまでのテキストを取得
    const range = document.createRange()
    range.selectNodeContents(this.contentTarget)
    range.setEnd(node, offset)

    return range.toString().length
  }

  // 「この箇所にマーカー」ボタンクリック
  openModal(event) {
    event.preventDefault()
    event.stopPropagation()

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

    // ツールチップを非表示
    this.hideTooltip()
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

    if (!this.currentSelection) {
      this.showError("選択範囲が見つかりません")
      return
    }

    const formData = new FormData(this.formTarget)
    formData.append("annotation[start_offset]", this.currentSelection.startOffset)
    formData.append("annotation[end_offset]", this.currentSelection.endOffset)
    formData.append("annotation[selected_text]", this.currentSelection.text)

    try {
      const response = await fetch(
        `/${this.threadSlugValue}/${this.postIdValue}/annotations`,
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

      if (data.success) {
        // 成功: モーダルを閉じてページをリロード（または動的にマーカーを追加）
        this.closeModal()
        window.location.reload()
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
