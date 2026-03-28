class DailyDigestJob < ApplicationJob
  queue_as :default

  # 1時間ごとに実行される（Solid Queue recurringで設定）
  # 現在時刻にマッチするユーザーにダイジェストメールを送信
  def perform
    current_time = Time.current
    current_hour = current_time.hour

    Rails.logger.info "DailyDigestJob: Running at #{current_hour}:00"

    # この時刻にダイジェスト配信を希望しているユーザーを取得（時間のみでマッチング、分は00のみ）
    NotificationSetting
      .email_mode_digest
      .where("EXTRACT(HOUR FROM digest_time) = ?", current_hour)
      .where("EXTRACT(MINUTE FROM digest_time) = ?", 0)
      .includes(:user)
      .find_each do |setting|
        send_digest_email(setting.user)
      end
  end

  private

  def send_digest_email(user)
    # 未読通知を取得（new_post のみ）
    unread_notifications = user.notifications
                                .unread
                                .where(action: :new_post)
                                .includes(:actor, notifiable: :thread)
                                .order(created_at: :desc)

    # 未読通知がなければスキップ
    return if unread_notifications.empty?

    Rails.logger.info "DailyDigestJob: Sending digest to #{user.username} (#{unread_notifications.count} notifications)"

    # ダイジェストメール送信
    UserMailer.daily_digest(user, unread_notifications).deliver_now

    # 送信後、通知を既読にする（オプション - 好みによる）
    # unread_notifications.update_all(read_at: Time.current)
  rescue => e
    Rails.logger.error("DailyDigestJob: Failed to send digest to #{user.username}: #{e.message}")
  end
end
