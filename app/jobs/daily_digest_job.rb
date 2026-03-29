class DailyDigestJob < ApplicationJob
  queue_as :default

  # 1時間ごとに実行される（Solid Queue recurringで設定）
  # 現在時刻にマッチするユーザーにダイジェストメールを送信
  def perform
    # Time.currentは設定されたタイムゾーン（Tokyo）で時刻を返す
    current_time = Time.current
    current_hour = current_time.hour

    Rails.logger.info "DailyDigestJob: Running at #{current_hour}:00 (#{Time.zone.name})"

    # この時刻にダイジェスト配信を希望しているユーザーを取得
    # 時間範囲での検索により、digest_timeカラムのインデックスを活用
    NotificationSetting
      .email_mode_digest
      .where(digest_time: current_time.beginning_of_hour..current_time.end_of_hour)
      .includes(:user)
      .find_each do |setting|
        send_digest_email(setting.user)
      end
  end

  private

  def send_digest_email(user)
    setting = user.notification_setting

    # 前回配信時刻以降の通知を取得（既読・未読問わず、new_post のみ）
    # 初回の場合は過去24時間
    since_time = setting&.last_digest_sent_at || 24.hours.ago

    notifications = user.notifications
                        .where(action: :new_post)
                        .where("created_at >= ?", since_time)
                        .includes(:actor, notifiable: :thread)
                        .order(created_at: :desc)

    # 通知がなければスキップ
    return if notifications.empty?

    Rails.logger.info "DailyDigestJob: Sending digest to #{user.username} (#{notifications.count} notifications since #{since_time})"

    # 配信時刻の更新とメール送信ジョブのエンキューをトランザクション内で実行し、原子性を保証します
    ActiveRecord::Base.transaction do
      # 配信時刻を先に記録（リトライ時の重複送信を防ぐ）
      setting&.update!(last_digest_sent_at: Time.current)

      # ダイジェストメール送信（非同期）
      UserMailer.daily_digest(user, notifications).deliver_later
    end
  end
end
