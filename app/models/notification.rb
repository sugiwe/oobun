class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :notifiable, polymorphic: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  enum :action, {
    new_post: "new_post",
    welcome: "welcome",
    test_notification: "test_notification",
    annotation_added: "annotation_added",
    annotation_invalidated: "annotation_invalidated"
  }

  # 通知作成後に各種配信を実行
  after_create_commit :deliver_notifications

  def mark_as_read!
    update(read_at: Time.current)
  end

  def unread?
    read_at.nil?
  end

  private

  def deliver_notifications
    # メール通知（非同期）
    EmailNotificationJob.perform_later(id)

    # Discord通知（非同期）- Phase 2で実装予定
    # if user.notification_setting&.use_discord?
    #   DiscordNotificationJob.perform_later(id)
    # end

    # Slack通知（非同期）- Phase 2で実装予定
    # if user.notification_setting&.use_slack?
    #   SlackNotificationJob.perform_later(id)
    # end
  end
end
