module MetaTagsHelper
  # デフォルトのサイト情報
  DEFAULT_SITE_NAME = "coconikki"
  DEFAULT_TITLE = "coconikki - 公開交換日記・往復書簡・文通サービス"
  DEFAULT_DESCRIPTION = "誰でも読める、公開交換日記・往復書簡・文通サービス。蓄積されていく対話を読み物として楽しめます。"

  # ページタイトルを生成
  def meta_title
    if content_for?(:meta_title)
      content_for(:meta_title)
    elsif content_for?(:title)
      content_for(:title)
    else
      DEFAULT_TITLE
    end
  end

  # ページ説明文を生成
  def meta_description
    if content_for?(:meta_description)
      content_for(:meta_description)
    else
      DEFAULT_DESCRIPTION
    end
  end

  # OGP画像URLを生成
  def meta_image
    if content_for?(:meta_image)
      content_for(:meta_image)
    else
      # デフォルトのOGP画像（app/assets/images/ogp.png）
      image_url("ogp.png")
    end
  end

  # 現在のページURLを取得（クエリパラメータを除外した正規化URL）
  def meta_url
    "#{request.base_url}#{request.path}"
  end

  # OGPタイプを取得（article or website）
  def meta_type
    content_for?(:meta_type) ? content_for(:meta_type) : "website"
  end

  # マークダウンテキストからプレーンテキストを抽出（description用）
  def extract_plain_text(markdown_text, max_length: 100)
    return "" if markdown_text.blank?

    # マークダウン記法を削除
    text = markdown_text.dup
    # コードブロックを削除（非貪欲マッチでバックティックが内部に含まれる場合に対応）
    text.gsub!(/```.*?```/m, "")
    # 画像を削除（! が残るのを防ぐ）
    text.gsub!(/!\[[^\]]*\]\([^\)]+\)/, "")
    # リンク: [text](url) → text
    text.gsub!(/\[([^\]]+)\]\([^\)]+\)/, '\1')
    # 太字・斜体: **text** or *text* → text（改行を跨がないようにしてリスト記号との誤判定を防ぐ）
    text.gsub!(/\*\*([^\*\n]+)\*\*/, '\1')
    text.gsub!(/\*([^\*\n]+)\*/, '\1')
    # 見出し: # text → text
    text.gsub!(/^#+\s+/, "")
    # インラインコード: `code` → code（改行を含まない）
    text.gsub!(/`([^`\n]+)`/, '\1')
    # 引用: > text → text
    text.gsub!(/^>\s+/, "")
    # リスト: - text, * text, 1. text → text（インデント対応）
    text.gsub!(/^\s*(?:[\-\*]|\d+\.)\s+/, "")
    # 改行を空白に変換
    text.gsub!(/\n+/, " ")
    # 複数の空白を1つに
    text.gsub!(/\s+/, " ")
    # 前後の空白を削除
    text.strip!

    # 最大文字数で切り詰め
    if text.length > max_length
      text[0...max_length] + "…"
    else
      text
    end
  end
end
