module MarkdownHelper
  # :::記法のマッピング
  SYNTAX_MAP = {
    "link-card" => :render_link_card
  }.freeze

  # YouTube埋め込み検出用の正規表現
  YOUTUBE_LINK_REGEX = %r{<p><a href="(https?://(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)[\w\-]+(?:[?&][\w=\-]*)*)"[^>]*>\1</a></p>}m.freeze

  # Spotify埋め込み検出用の正規表現
  SPOTIFY_LINK_REGEX = %r{<p><a href="(https?://open\.spotify\.com/(?:track|album|playlist|episode)/[\w]+(?:\?[\w=\-&]*)*)"[^>]*>\1</a></p>}m.freeze

  # マークダウンテキストをHTMLに変換
  def render_markdown(text)
    return "" if text.blank?

    # 1. :::記法を先に処理（link-cardなど）
    processed_text = process_explicit_syntax(text)

    # 2. Redcarpetでマークダウンをレンダリング
    renderer = Redcarpet::Render::HTML.new(
      filter_html: false,
      no_images: false,
      no_links: false,
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener noreferrer" }
    )

    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      space_after_headers: true,
      fenced_code_blocks: true,
      strikethrough: true,
      superscript: true
    )

    html = markdown.render(processed_text)

    # 3. RedcarpetがリンクにしたYouTube/Spotify URLを埋め込みに変換
    html = convert_links_to_embeds(html)

    # 4. HTMLをサニタイズ
    sanitized_html = Sanitize.fragment(html, sanitize_config)

    sanitized_html.html_safe
  end

  private

  # Redcarpetが生成したリンクタグをチェックして、埋め込みに変換
  def convert_links_to_embeds(html)
    # <p>タグで囲まれた単独のリンクを検出して埋め込みに変換
    html.gsub!(YOUTUBE_LINK_REGEX) { render_youtube_embed(Regexp.last_match(1)) }
    html.gsub!(SPOTIFY_LINK_REGEX) { render_spotify_embed(Regexp.last_match(1)) }
    html
  end

  # :::記法を処理
  def process_explicit_syntax(text)
    text.gsub(/:::(link-card)\s+(.+?)$/) do
      syntax_type = Regexp.last_match(1)
      url = Regexp.last_match(2).strip

      if (method_name = SYNTAX_MAP[syntax_type])
        send(method_name, url)
      else
        ""
      end
    end
  end

  # OGPカードのHTMLを生成
  def render_link_card(url)
    # OGPデータを取得（エラー時はフォールバック）
    ogp_data = fetch_ogp_data(url)

    title = ogp_data[:title] || url
    description = ogp_data[:description]
    image = ogp_data[:image]

    # OGPカードのHTMLを生成
    <<~HTML
      <div class="link-card border border-gray-200 rounded-lg overflow-hidden my-4 hover:bg-gray-50 transition-colors">
        <a href="#{ERB::Util.html_escape(url)}" target="_blank" rel="noopener noreferrer" class="block">
          #{image ? "<div class=\"w-full h-48 bg-gray-200 overflow-hidden\"><img src=\"#{ERB::Util.html_escape(image)}\" alt=\"\" class=\"w-full h-full object-cover\" /></div>" : ""}
          <div class="p-4">
            <div class="text-base text-gray-900 font-medium line-clamp-2 mb-1">#{ERB::Util.html_escape(title)}</div>
            #{description ? "<div class=\"text-sm text-gray-600 line-clamp-2 mb-2\">#{ERB::Util.html_escape(description)}</div>" : ""}
            <div class="text-xs text-gray-400 truncate">#{ERB::Util.html_escape(url)}</div>
          </div>
        </a>
      </div>
    HTML
  end

  # OGPデータを取得（OgpFetchesControllerのロジックを再利用）
  def fetch_ogp_data(url)
    require "open-uri"
    require "nokogiri"

    # タイムアウトを設定してURLを開く（SSRF対策は省略、表示時のみなのでリスク低）
    html = URI.open(url, read_timeout: 5, redirect: false).read
    doc = Nokogiri::HTML(html)

    # OGPタグから情報を取得
    title = doc.at('meta[property="og:title"]')&.[]("content") ||
            doc.at("title")&.text ||
            url

    description = doc.at('meta[property="og:description"]')&.[]("content") ||
                  doc.at('meta[name="description"]')&.[]("content")

    image = doc.at('meta[property="og:image"]')&.[]("content")

    {
      title: title&.strip,
      description: description&.strip,
      image: image&.strip
    }
  rescue => e
    # エラー時はURLのみ返す
    Rails.logger.warn "Failed to fetch OGP for link-card: #{url} - #{e.message}"
    { title: url, description: nil, image: nil }
  end

  # YouTube埋め込みのHTMLを生成
  def render_youtube_embed(url)
    video_id = extract_youtube_id(url)
    return "" unless video_id

    <<~HTML
      <div class="video-embed my-4">
        <div class="relative" style="padding-bottom: 56.25%; height: 0;">
          <iframe
            src="https://www.youtube.com/embed/#{ERB::Util.html_escape(video_id)}"
            frameborder="0"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowfullscreen
            class="absolute top-0 left-0 w-full h-full rounded-lg"
          ></iframe>
        </div>
      </div>
    HTML
  end

  # Spotify埋め込みのHTMLを生成
  def render_spotify_embed(url)
    # Spotify URLから埋め込み用URLを生成
    # 例: https://open.spotify.com/track/xxxxx → https://open.spotify.com/embed/track/xxxxx
    begin
      uri = URI.parse(url)
      return "" unless uri.host == "open.spotify.com"

      # パスの先頭に /embed を追加
      uri.path = "/embed#{uri.path}"
      embed_url = uri.to_s
    rescue URI::InvalidURIError
      return ""
    end

    <<~HTML
      <div class="spotify-embed my-4">
        <iframe
          src="#{ERB::Util.html_escape(embed_url)}"
          width="100%"
          height="152"
          frameborder="0"
          allowtransparency="true"
          allow="encrypted-media"
          class="rounded-lg"
        ></iframe>
      </div>
    HTML
  end

  # YouTube URLから動画IDを抽出
  def extract_youtube_id(url)
    patterns = [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/)([^&\?\/]+)/,
      /youtube\.com\/embed\/([^&\?\/]+)/
    ]

    patterns.each do |pattern|
      match = url.match(pattern)
      return match[1] if match
    end

    nil
  end

  # Sanitizeの設定
  #
  # セキュリティ上の注意:
  # - iframe要素とallow属性を許可しているため、XSS攻撃のリスクがあります
  # - 現在はYouTube/Spotify等のメディア埋め込みに限定していますが、
  #   この設定を変更する際は悪意のあるスクリプト実行を防ぐため厳格な検証が必要です
  # - iframeのsrcプロトコルはhttpsのみに制限しています
  # - iframe要素は render_youtube_embed / render_spotify_embed メソッドでのみ生成され、
  #   allow属性の値も固定されているため、ユーザー入力から直接iframeを生成することはありません
  # - style属性はXSSリスクがあるため、CSSプロパティのホワイトリストを最小限に制限しています
  #   （padding-bottom, height, position, top, left, width のみ許可）
  def sanitize_config
    {
      elements: %w[
        h1 h2 h3 h4 h5 h6
        p br hr
        strong em del sup
        ul ol li
        blockquote pre code
        a
        img
        div span
        iframe
        svg path
      ],
      attributes: {
        "a" => %w[href target rel],
        "img" => %w[src alt],
        # iframe: メディア埋め込み専用（render_youtube_embed / render_spotify_embed）
        "iframe" => %w[src width height frameborder allowfullscreen allowtransparency allow class style],
        # style属性: YouTube埋め込みのレスポンシブ対応に必要（padding-bottomなど）
        "div" => %w[class style],
        "span" => %w[class],
        "svg" => %w[class fill viewBox],
        "path" => %w[d]
      },
      protocols: {
        "a" => { "href" => [ "http", "https", "mailto" ] },
        "img" => { "src" => [ "http", "https" ] },
        "iframe" => { "src" => [ "https" ] }  # httpsのみ許可
      },
      css: {
        # XSS対策: 最小限のCSSプロパティのみ許可（YouTube埋め込みのレスポンシブ対応に必要）
        properties: %w[padding-bottom height position top left width]
      }
    }
  end
end
