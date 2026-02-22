xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title @thread.title
    xml.description @thread.description.presence || "#{@thread.users.map { |u| "@#{u.username}" }.join(" × ")} による文通"
    xml.link thread_url(@thread.slug)
    xml.language "ja"

    @posts.limit(10).each do |post|
      xml.item do
        xml.title post.title
        xml.description post.body
        xml.pubDate post.created_at.to_fs(:rfc822)
        xml.link thread_post_url(@thread.slug, post)
        xml.guid thread_post_url(@thread.slug, post), isPermaLink: "true"
        xml.author "#{post.user.username}@oobun (#{post.user.display_name})"
      end
    end
  end
end
