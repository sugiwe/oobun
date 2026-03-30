class UserMailer < ApplicationMailer
  # 新規投稿の通知メール
  def new_post_notification(notification)
    @notification = notification
    @user = notification.user
    @actor = notification.actor
    @post = notification.notifiable
    @thread = @post.thread

    # スレッド情報は常に最新のものを使用（paramsはスナップショット）
    @thread_title = @thread.title
    @thread_slug = @thread.slug
    @post_preview = notification.params["post_preview"]

    mail(
      to: @user.email,
      subject: "#{@actor.display_name} が「#{@thread_title}」に投稿しました - coconikki"
    )
  end

  # ダイジェストメール（1日1回まとめて通知）
  def daily_digest(user, notifications)
    @user = user
    @notifications = notifications

    # スレッドごとにグループ化
    @notifications_by_thread = notifications.group_by { |n| n.notifiable.thread }

    # 総通知数
    @total_count = notifications.count

    mail(
      to: @user.email,
      subject: "coconikki - #{@total_count}件の新着投稿があります"
    )
  end

  # テスト通知メール（即時配信モード時のみ送信）
  def test_notification(notification)
    @notification = notification
    @user = notification.user
    @message = notification.params["message"]

    mail(
      to: @user.email,
      subject: "coconikki - テスト通知"
    )
  end
end
