class Admin::DashboardController < Admin::ApplicationController
  # GET /admin
  def index
    # 基本的な統計情報を取得
    @stats = {
      users_count: User.count,
      threads_count: CorrespondenceThread.count,
      allowed_users_count: AllowedUser.count,
      login_invitations_count: LoginInvitation.count
    }
  end
end
