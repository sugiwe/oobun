class UserMailer < ApplicationMailer
  # 新規投稿の通知メール
  def new_post_notification(notification)
    @notification = notification
    @user = notification.user
    @actor = notification.actor
    @post = notification.notifiable
    @thread = @post.thread

    # メールパラメータから情報を取得
    @thread_title = notification.params["thread_title"]
    @thread_slug = notification.params["thread_slug"]
    @post_preview = notification.params["post_preview"]

    mail(
      to: @user.email,
      subject: "#{@actor.display_name} が「#{@thread_title}」に投稿しました - coconikki"
    )
  end
end
