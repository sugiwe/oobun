class UsersController < ApplicationController
  skip_before_action :require_login, only: [ :show ]
  before_action :set_user, only: [ :show, :edit, :update ]
  before_action :require_own_profile, only: [ :edit, :update ]

  def show
    @threads = @user.correspondence_threads
                    .where(visibility: "public")
                    .includes(:users, :memberships)
                    .recent_order
  end

  def edit
  end

  def update
    # 新しいアバターがアップロードされていない場合のみ削除チェックを処理
    should_remove_avatar = params.dig(:user, :remove_avatar) == "1" &&
                           user_params[:avatar].blank?

    if @user.update(user_params)
      @user.avatar.purge if should_remove_avatar
      redirect_to user_path(@user.username), notice: "プロフィールを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find_by!(username: params[:username])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "ユーザーが見つかりません"
  end

  def require_own_profile
    unless @user == current_user
      redirect_to user_path(@user.username), alert: "自分のプロフィールのみ編集できます"
    end
  end

  def user_params
    params.require(:user).permit(:display_name, :username, :bio, :avatar)
  end
end
