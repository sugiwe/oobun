import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)

      const originalText = this.element.textContent
      this.element.textContent = 'コピーしました！'
      this.element.classList.add('bg-green-600', 'hover:bg-green-700')
      this.element.classList.remove('bg-gray-900', 'hover:bg-gray-700')

      setTimeout(() => {
        this.element.textContent = originalText
        this.element.classList.remove('bg-green-600', 'hover:bg-green-700')
        this.element.classList.add('bg-gray-900', 'hover:bg-gray-700')
      }, 2000)
    } catch (err) {
      console.error('コピーに失敗しました:', err)
      alert('コピーに失敗しました')
    }
  }
}
