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
