class DailyDigestJob < ApplicationJob
  queue_as :default

  # 1時間ごとに実行される（Solid Queue recurringで設定）
  # 現在時刻にマッチするユーザーにダイジェストメールを送信
  def perform
    # Time.currentは設定されたタイムゾーン（Tokyo）で時刻を返す
    # digest_timeもTime.zone.parseで同じタイムゾーンで保存されているため、一致判定は正しく動作する
    current_time = Time.current
    current_hour = current_time.hour

    Rails.logger.info "DailyDigestJob: Running at #{current_hour}:00 (#{Time.zone.name})"

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
    # 過去24時間以内に作成された通知を取得（既読・未読問わず、new_post のみ）
    notifications_last_24h = user.notifications
                                  .where(action: :new_post)
                                  .where("created_at >= ?", 24.hours.ago)
                                  .includes(:actor, notifiable: :thread)
                                  .order(created_at: :desc)

    # 通知がなければスキップ
    return if notifications_last_24h.empty?

    Rails.logger.info "DailyDigestJob: Sending digest to #{user.username} (#{notifications_last_24h.count} notifications from last 24 hours)"

    # ダイジェストメール送信
    UserMailer.daily_digest(user, notifications_last_24h).deliver_now
  rescue => e
    Rails.logger.error("DailyDigestJob: Failed to send digest to #{user.username}: #{e.message}\n#{e.backtrace.join("\n")}")
  end
end
