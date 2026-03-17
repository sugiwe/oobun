module MarkdownHelper
  # マークダウンテキストをHTMLに変換
  def render_markdown(text)
    return "" if text.blank?

    # 独自記法を処理
    processed_text = process_custom_syntax(text)

    # Redcarpetでマークダウンをレンダリング
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

    # HTMLをサニタイズ
    sanitized_html = Sanitize.fragment(html, sanitize_config)

    sanitized_html.html_safe
  end

  private

  # 独自記法を処理してHTMLに変換
  def process_custom_syntax(text)
    # :::link-card URL を処理
    text = text.gsub(/:::link-card\s+(.+?)$/) do
      url = Regexp.last_match(1).strip
      render_link_card(url)
    end

    # :::embed-youtube URL を処理
    text = text.gsub(/:::embed-youtube\s+(.+?)$/) do
      url = Regexp.last_match(1).strip
      render_youtube_embed(url)
    end

    # :::embed-spotify URL を処理
    text = text.gsub(/:::embed-spotify\s+(.+?)$/) do
      url = Regexp.last_match(1).strip
      render_spotify_embed(url)
    end

    # :::embed-x URL を処理
    text = text.gsub(/:::embed-x\s+(.+?)$/) do
      url = Regexp.last_match(1).strip
      render_x_embed(url)
    end

    # :::embed-instagram URL を処理
    text = text.gsub(/:::embed-instagram\s+(.+?)$/) do
      url = Regexp.last_match(1).strip
      render_instagram_embed(url)
    end

    text
  end

  # OGPカードのHTMLを生成
  def render_link_card(url)
    # TODO: OGP取得機能を実装する際に、ここで実際のOGPデータを取得する
    # 現在はプレースホルダーとして簡易版を返す
    <<~HTML
      <div class="link-card border border-gray-200 rounded-lg p-4 my-4 hover:bg-gray-50">
        <a href="#{ERB::Util.html_escape(url)}" target="_blank" rel="noopener noreferrer" class="block">
          <div class="text-sm text-gray-900 font-medium">#{ERB::Util.html_escape(url)}</div>
          <div class="text-xs text-gray-500 mt-1">リンクカード</div>
        </a>
      </div>
    HTML
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
    embed_url = url.sub("open.spotify.com/", "open.spotify.com/embed/")

    <<~HTML
      <div class="spotify-embed my-4">
        <iframe
          src="#{ERB::Util.html_escape(embed_url)}"
          width="100%"
          height="352"
          frameborder="0"
          allowtransparency="true"
          allow="encrypted-media"
          class="rounded-lg"
        ></iframe>
      </div>
    HTML
  end

  # X (Twitter) 埋め込みのHTMLを生成
  def render_x_embed(url)
    # X/Twitterの埋め込みは通常、oEmbedを使用するが、
    # 今回は簡易的にリンクカード風に表示
    <<~HTML
      <div class="x-embed border border-gray-200 rounded-lg p-4 my-4 bg-gray-50">
        <a href="#{ERB::Util.html_escape(url)}" target="_blank" rel="noopener noreferrer" class="block">
          <div class="flex items-center gap-2">
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/>
            </svg>
            <div class="text-sm text-gray-900 font-medium">Xで見る</div>
          </div>
          <div class="text-xs text-gray-500 mt-2">#{ERB::Util.html_escape(url)}</div>
        </a>
      </div>
    HTML
  end

  # Instagram埋め込みのHTMLを生成
  def render_instagram_embed(url)
    # Instagramの埋め込みもoEmbedを使用するのが一般的だが、
    # 今回は簡易的にリンクカード風に表示
    <<~HTML
      <div class="instagram-embed border border-gray-200 rounded-lg p-4 my-4 bg-gray-50">
        <a href="#{ERB::Util.html_escape(url)}" target="_blank" rel="noopener noreferrer" class="block">
          <div class="flex items-center gap-2">
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z"/>
            </svg>
            <div class="text-sm text-gray-900 font-medium">Instagramで見る</div>
          </div>
          <div class="text-xs text-gray-500 mt-2">#{ERB::Util.html_escape(url)}</div>
        </a>
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
        "iframe" => %w[src width height frameborder allowfullscreen allowtransparency allow class style],
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
        properties: %w[padding-bottom height position top left width]
      }
    }
  end
end
