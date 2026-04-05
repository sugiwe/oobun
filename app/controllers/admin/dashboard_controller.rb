class Admin::DashboardController < Admin::ApplicationController
  # GET /admin
  def index
    # 基本的な統計情報を取得
    @stats = {
      users_count: User.count,
      threads_count: CorrespondenceThread.count
    }

    # 月間登録枠の状況を取得
    @monthly_quota = MonthlySignupQuota.current_month
  end
end
