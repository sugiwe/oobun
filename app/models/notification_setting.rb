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

  # カスタムセッター: "HH:MM:SS"形式を"HH:MM"形式に正規化
  def digest_time=(value)
    # Timeオブジェクトの場合は "HH:MM" 形式に変換
    value = value.strftime("%H:%M") if value.respond_to?(:strftime)

    if value.is_a?(String) && value.match?(/\A\d{2}:\d{2}(:\d{2})?\z/)
      # "HH:MM:SS" または "HH:MM" 形式を "HH:MM" に統一
      super(value.split(":")[0..1].join(":"))
    else
      super(value)
    end
  end

  # ダイジェスト配信時刻（時と分を返す）
  def digest_hour
    return 8 if digest_time.blank?
    digest_time.split(":").first.to_i
  end

  def digest_minute
    return 0 if digest_time.blank?
    digest_time.split(":")[1].to_i
  end

  # 配信時刻の文字列表現（UI表示用）
  def digest_time_display
    digest_time.presence || "08:00"
  end

  # 即時配信が可能かチェック（副作用なし、CQS原則に準拠）
  def can_send_realtime_email?
    return false unless email_mode_realtime?

    current_count = counter_needs_reset? ? 0 : email_count_this_month
    current_count < REALTIME_MONTHLY_LIMIT
  end

  # 即時配信後にカウンターをインクリメント
  def increment_email_count!
    return unless email_mode_realtime?

    # with_lockブロック内で実行されるため、update!でアトミックに更新
    new_count = email_count_this_month + 1
    attrs_to_update = { email_count_this_month: new_count }
    if new_count >= REALTIME_MONTHLY_LIMIT
      attrs_to_update[:email_mode] = :digest
    end
    update!(attrs_to_update)
  end

  # 残り配信数（月初のリセットを考慮）
  def remaining_emails_this_month
    return nil unless email_mode_realtime?

    current_count = counter_needs_reset? ? 0 : email_count_this_month
    [ REALTIME_MONTHLY_LIMIT - current_count, 0 ].max
  end

  # 月が変わっていたらカウンターをリセット（public: ジョブから明示的に呼び出す）
  def reset_counter_if_needed!
    if counter_needs_reset?
      update!(
        email_count_this_month: 0,
        email_count_reset_at: Date.current.beginning_of_month
      )
    end
  end

  private

  def disable_webhooks_if_urls_blank
    self.use_discord = false if discord_webhook_url.blank?
    self.use_slack = false if slack_webhook_url.blank?
  end

  # カウンターがリセット必要かチェック
  def counter_needs_reset?
    current_month = Date.current.beginning_of_month
    email_count_reset_at.nil? || email_count_reset_at < current_month
  end
end
