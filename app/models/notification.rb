class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :notifiable, polymorphic: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  enum :action, {
    new_post: "new_post"
  }

  # Phase 2で有効化
  # after_create_commit :deliver_notifications

  def mark_as_read!
    update(read_at: Time.current)
  end

  def unread?
    read_at.nil?
  end

  # Phase 2で実装
  # def deliver_notifications
  #   # Discord通知（非同期）
  #   if user.notification_setting&.use_discord?
  #     DiscordNotificationJob.perform_later(id)
  #   end
  #
  #   # Slack通知（非同期）
  #   if user.notification_setting&.use_slack?
  #     SlackNotificationJob.perform_later(id)
  #   end
  # end
end
