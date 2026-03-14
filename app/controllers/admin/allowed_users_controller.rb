class Admin::AllowedUsersController < Admin::ApplicationController
  before_action :set_allowed_user, only: [ :edit, :update, :destroy ]

  # GET /admin/allowed_users
  def index
    @allowed_users = AllowedUser.includes(:invited_by).order(created_at: :desc)
  end

  # GET /admin/allowed_users/new
  def new
    @allowed_user = AllowedUser.new
  end

  # POST /admin/allowed_users
  def create
    @allowed_user = AllowedUser.new(allowed_user_params)
    @allowed_user.added_by_admin = true

    if @allowed_user.save
      redirect_to admin_allowed_users_path, notice: "ログイン許可ユーザーを追加しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /admin/allowed_users/:id/edit
  def edit
  end

  # PATCH/PUT /admin/allowed_users/:id
  def update
    if @allowed_user.update(allowed_user_params)
      redirect_to admin_allowed_users_path, notice: "ログイン許可ユーザーを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/allowed_users/:id
  def destroy
    @allowed_user.destroy
    redirect_to admin_allowed_users_path, notice: "ログイン許可を削除しました"
  end

  private

  def set_allowed_user
    @allowed_user = AllowedUser.find(params[:id])
  end

  def allowed_user_params
    params.require(:allowed_user).permit(:email, :note, :contacted)
  end
end
