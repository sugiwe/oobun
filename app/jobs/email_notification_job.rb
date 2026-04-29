class EmailNotificationJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(notification_id)
    notification = Notification.find(notification_id)
    user = notification.user
    setting = user.notification_setting || user.create_notification_setting

    # メール通知がOFFの場合はスキップ
    return if setting.email_mode_off?

    # 付箋通知は即時配信しない（ダイジェストのみ）
    # 理由: 短時間に複数の付箋がつくことがあり、メール通知が大量になるのを防ぐため
    return if notification.annotation_added? || notification.annotation_invalidated?

    # 即時配信モードの場合のみメール送信
    if setting.email_mode_realtime?
      # test_notification の場合
      if notification.test_notification?
        send_realtime_email(setting) do
          UserMailer.test_notification(notification).deliver_later
        end
        return
      end

      # 通常の投稿通知（new_post）の場合
      send_realtime_email(setting) do
        UserMailer.new_post_notification(notification).deliver_later
      end
    end

    # ダイジェストモードの場合はここでは何もしない（DailyDigestJobで処理）
  rescue => e
    Rails.logger.error("Email notification failed for notification #{notification_id}: #{e.message}\n#{e.backtrace.join("\n")}")
    # 失敗してもアプリ内通知は残る
    raise # リトライするために再raiseする
  end

  private

  # 即時配信モードでメール送信を試みる（残数チェックとカウンター管理を含む）
  def send_realtime_email(setting)
    # 悲観的ロックで競合を防止（複数の通知が同時発生した場合）
    can_send = setting.with_lock do
      # 月初のカウンターリセットを明示的に実行
      setting.reset_counter_if_needed!

      # 配信可能かチェック
      next false unless setting.can_send_realtime_email?

      # カウンターをインクリメント（上限到達時は自動的にダイジェストに切り替わる）
      setting.increment_email_count!

      true
    end

    # ロック解放後にメール送信（非同期）
    yield if can_send
  end
end
