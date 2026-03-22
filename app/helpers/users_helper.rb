module UsersHelper
  # bioテキスト内のURLを自動的にリンクに変換する
  def auto_link_bio(text)
    return "" if text.blank?

    # URLの正規表現パターン
    url_pattern = %r{(https?://[^\s<]+)}

    # URLをリンクに変換（markdown-bodyのリンクスタイルに合わせる）
    html = text.gsub(url_pattern) do |url|
      link_to url, url, target: "_blank", rel: "noopener noreferrer", class: "text-gray-600 hover:text-gray-900 underline"
    end

    # 改行を保持しつつHTMLとして表示
    simple_format(html, {}, sanitize: false)
  end
end
