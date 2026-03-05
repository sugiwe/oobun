xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom", "xmlns:content" => "http://purl.org/rss/1.0/modules/content/" do
  xml.channel do
    xml.title @thread.title
    xml.description @thread.description.presence || "#{@thread.users.map { |u| "@#{u.username}" }.join(" × ")} による文通"
    xml.link thread_url(@thread.slug)
    xml.language "ja"
    xml.tag! "atom:link", href: thread_url(@thread.slug, format: :rss), rel: "self", type: "application/rss+xml"

    # スレッドのサムネイル画像（チャンネル画像）
    if @thread.thumbnail.attached?
      xml.image do
        xml.url url_for(@thread.thumbnail)
        xml.title @thread.title
        xml.link thread_url(@thread.slug)
      end
    end

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

        # 投稿のサムネイル画像（enclosure）
        if post.thumbnail.attached?
          xml.enclosure url: url_for(post.thumbnail),
                        type: post.thumbnail.content_type,
                        length: post.thumbnail.byte_size
        end
      end
    end
  end
end
