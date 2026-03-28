class EmailNotificationJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(notification_id)
    notification = Notification.find(notification_id)
    user = notification.user
    setting = user.notification_setting

    # メール通知がOFFの場合はスキップ
    return if setting.email_mode_off?

    # 即時配信モードの場合は制限チェック
    if setting.email_mode_realtime?
      # 配信可能かチェック
      return unless setting.can_send_realtime_email?

      # メール送信
      UserMailer.new_post_notification(notification).deliver_now

      # カウンターをインクリメント（上限到達時は自動的にダイジェストに切り替わる）
      setting.increment_email_count!
    end

    # ダイジェストモードの場合はここでは何もしない（DailyDigestJobで処理）
  rescue => e
    Rails.logger.error("Email notification failed for notification #{notification_id}: #{e.message}")
    # 失敗してもアプリ内通知は残る
    raise # リトライするために再raiseする
  end
end
