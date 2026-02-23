class UsersController < ApplicationController
  skip_before_action :require_login, only: [ :show ]

  def show
    @user = User.find_by!(username: params[:username])
    @threads = @user.correspondence_threads
                    .where(visibility: "public")
                    .includes(:users, :memberships)
                    .recent_order
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "ユーザーが見つかりません"
  end
end
