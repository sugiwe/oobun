require "open-uri"
require "nokogiri"
require "resolv"
require "ipaddr"

class OgpFetchesController < ApplicationController
  # SSRF対策: ブロックするプライベートIPアドレス範囲
  PRIVATE_IP_RANGES = [
    IPAddr.new("10.0.0.0/8"),       # プライベートネットワーク
    IPAddr.new("172.16.0.0/12"),    # プライベートネットワーク
    IPAddr.new("192.168.0.0/16"),   # プライベートネットワーク
    IPAddr.new("127.0.0.0/8"),      # ループバック
    IPAddr.new("169.254.0.0/16"),   # リンクローカル
    IPAddr.new("::1/128"),          # IPv6 ループバック
    IPAddr.new("fc00::/7"),         # IPv6 プライベート
    IPAddr.new("fe80::/10")         # IPv6 リンクローカル
  ].freeze

  def create
    url = params[:url].to_s.strip

    if url.blank?
      render json: { error: "URLが指定されていません" }, status: :bad_request
      return
    end

    ogp_data = fetch_ogp(url)
    render json: ogp_data
  rescue ArgumentError => e
    # SSRF対策でブロックされた、または不正なURL
    Rails.logger.warn "OGP fetch blocked or invalid: #{url} - #{e.message}"
    render json: { title: url, description: nil, image: nil }
  rescue URI::InvalidURIError => e
    # 不正なURL形式
    Rails.logger.error "Invalid URL for OGP fetch: #{url} - #{e.message}"
    render json: { title: url, description: nil, image: nil }
  rescue Nokogiri::XML::SyntaxError => e
    # HTML解析エラー
    Rails.logger.error "HTML parse error for OGP fetch: #{url} - #{e.message}"
    render json: { title: url, description: nil, image: nil }
  end

  private

  def fetch_ogp(url)
    # SSRF対策: URLを検証
    validate_url_for_ssrf!(url)

    # タイムアウトを設定してURLを開く
    # SSRF対策: リダイレクトを無効化（リダイレクト先の検証を回避するため）
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
  rescue OpenURI::HTTPError, SocketError, Timeout::Error => e
    Rails.logger.warn "Failed to fetch OGP for #{url}: #{e.message}"
    # エラー時はURLをタイトルとして返す
    { title: url, description: nil, image: nil }
  end

  # SSRF対策: URLが安全かチェック
  def validate_url_for_ssrf!(url)
    uri = URI.parse(url)

    # HTTPまたはHTTPSのみ許可
    unless %w[http https].include?(uri.scheme)
      raise ArgumentError, "HTTP/HTTPS以外のスキームは許可されていません: #{uri.scheme}"
    end

    # IPアドレスを解決
    address = Resolv.getaddress(uri.host)
    ip = IPAddr.new(address)

    # プライベートIPアドレスをブロック
    if PRIVATE_IP_RANGES.any? { |range| range.include?(ip) }
      raise ArgumentError, "プライベートIPアドレスへのアクセスは許可されていません: #{address}"
    end
  rescue Resolv::ResolvError => e
    raise ArgumentError, "ホスト名を解決できません: #{uri.host}"
  end
end
