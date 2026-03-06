xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom", "xmlns:content" => "http://purl.org/rss/1.0/modules/content/", "xmlns:itunes" => "http://www.itunes.com/dtds/podcast-1.0.dtd", "xmlns:media" => "http://search.yahoo.com/mrss/" do
  xml.channel do
    # RSSフィードの表示条件:
    # - free: 投稿内容を表示
    # - paid: フィードは生成するが「有料コンテンツ」メッセージのみ（投稿は非表示）
    # - draft: 「非公開中」メッセージのみ（投稿は非表示）
    #
    # 理由: RSSは認証機能がないため、有料コンテンツ（paid）をフィードで
    # 配信すると課金制御ができない。有料コンテンツはcoconikki内で閲覧する。
    case @thread.status
    when "paid"
      xml.title "💎 #{@thread.title}（有料コンテンツ）"
      xml.description "この交換日記は有料コンテンツです。coconikkiにログインして購読すると全文を読めます。"
    when "free"
      xml.title @thread.title
      xml.description @thread.description.presence || "#{@thread.users.map { |u| "@#{u.username}" }.join(" × ")} による文通"
    when "draft"
      xml.title "【非公開中】"
      xml.description "このフィードは現在非公開になっています。"
    end
    xml.link thread_url(@thread.slug)
    xml.language "ja"
    xml.tag! "atom:link", href: thread_url(@thread.slug, format: :rss), rel: "self", type: "application/rss+xml"

    # スレッドのサムネイル画像（チャンネル画像）
    if @thread.thumbnail.attached?
      # RSS 2.0 標準の image 要素
      xml.image do
        xml.url rails_blob_url(@thread.thumbnail)
        xml.title @thread.title
        xml.link thread_url(@thread.slug)
      end

      # iTunes RSS拡張によるカバーアート（モダンなRSSリーダーで広くサポートされている）
      xml.tag! "itunes:image", href: rails_blob_url(@thread.thumbnail)
    end

    # 無料公開の場合のみ投稿を表示
    if @thread.free?
      @posts.limit(10).each do |post|
        xml.item do
          xml.title post.title

          # 本文をHTMLとして提供（改行を保持）
          xml.tag! "content:encoded" do
            xml.cdata! simple_format(post.body)
          end

          # プレーンテキストの説明
          xml.description post.body

          xml.pubDate post.created_at.to_fs(:rfc822)
          xml.link thread_post_url(@thread.slug, post)
          xml.guid thread_post_url(@thread.slug, post), isPermaLink: "true"
          xml.author "#{post.user.display_name} (@#{post.user.username})"

          # 投稿のサムネイル画像（enclosure + Media RSS）
          if post.thumbnail.attached?
            xml.enclosure url: rails_blob_url(post.thumbnail),
                          type: post.thumbnail.content_type,
                          length: post.thumbnail.byte_size
            xml.tag! "media:content", url: rails_blob_url(post.thumbnail),
                     type: post.thumbnail.content_type,
                     medium: "image"
          end
        end
      end
    end
  end
end
