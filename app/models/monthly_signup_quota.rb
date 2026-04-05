class MonthlySignupQuota < ApplicationRecord
  validates :year_month, presence: true, uniqueness: true,
    format: { with: /\A\d{4}-\d{2}\z/, message: "YYYY-MM形式で入力してください" }
  validates :quota_limit, presence: true, numericality: { greater_than: 0 }
  validates :signups_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # 今月の枠を取得または作成
  def self.current_month
    year_month = Time.current.in_time_zone("Tokyo").strftime("%Y-%m")
    find_or_create_by!(year_month: year_month)
  end

  # 月間枠に空きがあるかチェック
  def available?
    signups_count < quota_limit
  end

  # 登録数をインクリメント
  def increment_signups!
    increment!(:signups_count)
  end

  # 月間枠をリセット（翌月用）
  def self.reset_for_next_month!
    next_month = 1.month.from_now.in_time_zone("Tokyo").strftime("%Y-%m")
    find_or_create_by!(year_month: next_month) do |quota|
      quota.quota_limit = 100
      quota.signups_count = 0
    end
  end

  # 残り枠数
  def remaining
    quota_limit - signups_count
  end
end
