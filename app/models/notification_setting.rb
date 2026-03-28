class NotificationSetting < ApplicationRecord
  belongs_to :user

  # 即時配信の月次上限
  REALTIME_MONTHLY_LIMIT = 100

  # メール配信モード
  enum :email_mode, {
    off: "off",           # メール通知なし
    digest: "digest",     # ダイジェスト配信（デフォルト）
    realtime: "realtime"  # 即時配信（100通/月制限）
  }, prefix: true

  # バリデーション
  validates :discord_webhook_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[https]), allow_blank: true }
  validates :slack_webhook_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[https]), allow_blank: true }
  validates :digest_time, presence: true
  validates :email_mode, presence: true, inclusion: { in: email_modes.keys }

  # webhook URLが設定されていない場合は、use_discord/use_slackをfalseにする
  before_save :disable_webhooks_if_urls_blank

  # ダイジェスト配信時刻（時と分を返す）
  def digest_hour
    digest_time&.hour || 8
  end

  def digest_minute
    digest_time&.min || 0
  end

  # 配信時刻の文字列表現（UI表示用）
  def digest_time_display
    digest_time&.strftime("%H:%M") || "08:00"
  end

  # 即時配信が可能かチェック
  def can_send_realtime_email?
    return false unless email_mode_realtime?

    reset_counter_if_needed!
    email_count_this_month < REALTIME_MONTHLY_LIMIT
  end

  # 即時配信後にカウンターをインクリメント
  def increment_email_count!
    return unless email_mode_realtime?

    increment!(:email_count_this_month)
    reload  # increment!後に最新の値を取得

    # 上限到達時にダイジェストに自動切り替え
    if email_count_this_month >= REALTIME_MONTHLY_LIMIT
      update!(email_mode: :digest)
    end
  end

  # 残り配信数
  def remaining_emails_this_month
    return nil unless email_mode_realtime?
    [REALTIME_MONTHLY_LIMIT - email_count_this_month, 0].max
  end

  private

  def disable_webhooks_if_urls_blank
    self.use_discord = false if discord_webhook_url.blank?
    self.use_slack = false if slack_webhook_url.blank?
  end

  # 月が変わっていたらカウンターをリセット
  def reset_counter_if_needed!
    current_month = Date.current.beginning_of_month

    if email_count_reset_at.nil? || email_count_reset_at < current_month
      update!(
        email_count_this_month: 0,
        email_count_reset_at: current_month
      )
    end
  end
end
