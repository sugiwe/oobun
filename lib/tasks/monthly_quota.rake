namespace :monthly_quota do
  desc "翌月の月間登録枠を作成（毎月1日に実行）"
  task reset: :environment do
    quota = MonthlySignupQuota.reset_for_next_month!
    puts "月間登録枠を作成しました: #{quota.year_month} (上限: #{quota.quota_limit}人)"
  end

  desc "今月の月間登録枠の状況を表示"
  task status: :environment do
    quota = MonthlySignupQuota.current_month
    puts "=" * 50
    puts "月間登録枠の状況"
    puts "=" * 50
    puts "対象月:     #{quota.year_month}"
    puts "上限:       #{quota.quota_limit}人"
    puts "登録済み:   #{quota.signups_count}人"
    puts "残り:       #{quota.remaining}人"
    puts "状態:       #{quota.available? ? '受付中' : '上限到達'}"
    puts "=" * 50
  end
end
