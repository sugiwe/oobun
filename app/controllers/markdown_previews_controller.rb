class MarkdownPreviewsController < ApplicationController
  def create
    text = params[:text].to_s

    if text.blank?
      render json: { html: '<div class="text-gray-400 text-sm">プレビューする内容がありません</div>' }
      return
    end

    html = helpers.render_markdown(text)
    render json: { html: html }
  rescue ArgumentError, Encoding::CompatibilityError => e
    # マークダウン処理時のエンコーディングエラーなど
    Rails.logger.error "Markdown preview error: #{e.class} - #{e.message}"
    render json: { html: '<div class="text-red-500 text-sm">プレビューの読み込みに失敗しました</div>' }, status: :unprocessable_entity
  end
end
