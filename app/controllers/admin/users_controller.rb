class Admin::UsersController < Admin::ApplicationController
  # GET /admin/users
  def index
    @users = User.order(created_at: :desc).page(params[:page])
  end

  # GET /admin/users/:id
  def show
    @user = User.find(params[:id])
    @memberships = @user.memberships.includes(:thread).order(created_at: :desc)
    @allowed_user = AllowedUser.includes(:login_invitation).find_by(email: @user.normalized_email)
  end
end
