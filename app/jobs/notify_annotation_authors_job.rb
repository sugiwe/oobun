class NotifyAnnotationAuthorsJob < ApplicationJob
  queue_as :default

  def perform(post_id, user_ids)
    post = Post.find_by(id: post_id)
    return unless post

    User.where(id: user_ids).find_each do |annotation_author|
      # 投稿者自身には通知しない
      next if annotation_author.id == post.user_id

      annotation_author.notifications.create!(
        actor: post.user,
        notifiable: post,
        action: :annotation_invalidated
      )
    end
  end
end
