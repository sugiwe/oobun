class MonthlySignupQuota < ApplicationRecord
  self.table_name = "monthly_signup_quotas"

  # デフォルトの月間登録枠
  DEFAULT_QUOTA_LIMIT = 100

  validates :year_month, presence: true, uniqueness: true,
    format: { with: /\A\d{4}-\d{2}\z/, message: "YYYY-MM形式で入力してください" }
  validates :quota_limit, presence: true, numericality: { greater_than: 0 }
  validates :signups_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # 今月の枠を取得または作成
  def self.current_month
    year_month = Time.current.in_time_zone("Tokyo").strftime("%Y-%m")
    # デフォルト値はマイグレーションで設定されているため、ブロック不要
    find_or_create_by!(year_month: year_month)
  end

  # 月間枠に空きがあるかチェック
  def available?
    signups_count < quota_limit
  end

  # 登録数をインクリメント（アトミック操作）
  def increment_signups!
    self.class.increment_counter(:signups_count, id)
  end

  # 月間枠をリセット（翌月用）
  def self.reset_for_next_month!
    next_month = Time.current.in_time_zone("Tokyo").next_month.strftime("%Y-%m")
    create_or_find_by!(year_month: next_month) do |quota|
      quota.quota_limit = DEFAULT_QUOTA_LIMIT
      quota.signups_count = 0
    end
  end

  # 残り枠数
  def remaining
    quota_limit - signups_count
  end
end
