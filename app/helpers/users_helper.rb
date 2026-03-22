module UsersHelper
  # bioテキスト内のURLを自動的にリンクに変換する
  # XSS対策のため、まずテキストをエスケープしてからURLのみリンク化する
  def auto_link_bio(text)
    return "" if text.blank?

    # まずHTMLエスケープで安全にする
    escaped_text = ERB::Util.html_escape(text)

    # URLの正規表現パターン
    url_pattern = %r{(https?://[^\s<]+)}

    # エスケープ済みテキスト内のURLをリンクに変換（markdown-bodyのリンクスタイルに合わせる）
    html_with_links = escaped_text.gsub(url_pattern) do |url|
      link_to url, url, target: "_blank", rel: "noopener noreferrer", class: "text-gray-600 hover:text-gray-900 underline"
    end

    # 改行を保持しつつHTMLとして表示（エスケープ済みなのでsanitize不要）
    simple_format(html_with_links, {}, sanitize: false).html_safe
  end
end
