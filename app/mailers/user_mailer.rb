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
    # notifiable が Post の場合: notifiable.thread
    # notifiable が Annotation の場合: notifiable.post.thread
    # 孤立通知（notifiable が削除済み）や付箋の親投稿が削除されている場合も考慮して安全呼び出し（&.）を使用
    @notifications_by_thread = notifications.group_by do |n|
      if n.notifiable&.is_a?(Post)
        n.notifiable.thread
      elsif n.notifiable&.is_a?(Annotation)
        n.notifiable.post&.thread
      else
        nil
      end
    end.except(nil)

    # 総通知数
    @total_count = notifications.count

    # 付箋通知の数
    @annotation_count = notifications.count { |n| n.annotation_added? || n.annotation_invalidated? }

    # 投稿通知の数
    @post_count = notifications.count { |n| n.new_post? }

    mail(
      to: @user.email,
      subject: "coconikki - #{@total_count}件の新着があります"
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
