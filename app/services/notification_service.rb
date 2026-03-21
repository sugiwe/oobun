class NotificationService
  # 新規投稿の通知を作成
  def self.notify_new_post(post)
    new(post).notify_new_post
  end

  def initialize(post)
    @post = post
    @thread = post.thread
    @actor = post.user
  end

  def notify_new_post
    # N+1クエリを避けるためにnotification_settingをeager loadする
    recipients.includes(:notification_setting).each do |recipient|
      setting = recipient.notification_setting
      # 安全のため、設定が見つからない場合は通知を送信しない
      next unless setting

      is_member = member_ids.include?(recipient.id)
      is_subscriber = subscriber_ids.include?(recipient.id)

      # ユーザーの通知設定を確認してから通知を送信
      if (is_member && setting.notify_member_posts) || (is_subscriber && setting.notify_subscription_posts)
        create_notification(recipient)
      end
    end
  end

  private

  def recipients
    # N+1問題を回避：distinctで重複排除、一度のクエリで取得
    User.where(id: member_ids + subscriber_ids)
        .where.not(id: @actor.id)
        .distinct
  end

  def member_ids
    @member_ids ||= @thread.memberships.pluck(:user_id)
  end

  def subscriber_ids
    @subscriber_ids ||= @thread.subscriptions.pluck(:user_id)
  end

  def create_notification(recipient)
    Notification.create!(
      user: recipient,
      actor: @actor,
      notifiable: @post,
      action: :new_post,
      params: {
        thread_title: @thread.title,
        thread_slug: @thread.slug,
        post_preview: @post.body.truncate(100)
      }
    )
  end
end
