require "open-uri"
require "nokogiri"

class OgpFetchesController < ApplicationController
  def create
    url = params[:url].to_s.strip

    if url.blank?
      render json: { error: "URLが指定されていません" }, status: :bad_request
      return
    end

    ogp_data = fetch_ogp(url)
    render json: ogp_data
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
    # タイムアウトを設定してURLを開く
    html = URI.open(url, read_timeout: 5, redirect: true).read
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
end
