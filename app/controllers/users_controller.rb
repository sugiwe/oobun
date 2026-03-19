class UsersController < ApplicationController
  skip_before_action :require_login, only: [ :show ]
  before_action :set_user, only: [ :show, :edit, :update, :delete_confirmation, :destroy ]
  before_action :require_own_profile, only: [ :edit, :update, :delete_confirmation, :destroy ]

  def show
    # ログインユーザーが自分のページを見る場合は非公開も表示
    # 他人のページを見る場合は公開スレッドのみ表示
    threads_scope = @user.correspondence_threads
                         .includes(:users, :memberships)

    @threads = if logged_in? && @user == current_user
      threads_scope.recent_order
    else
      threads_scope.public_threads.recent_order
    end
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

  # GET /@:username/delete - 退会確認ページ
  def delete_confirmation
    @participated_threads = @user.correspondence_threads.includes(:users, :memberships)
  end

  # DELETE /@:username - アカウント削除（退会）
  def destroy
    # ユーザー名確認
    if params[:username_confirmation] != @user.username
      redirect_to delete_confirmation_user_path(@user.username), alert: "ユーザー名が一致しません"
      return
    end

    ActiveRecord::Base.transaction do
      # 1. 投稿内容を匿名化（空文字列に変更）
      @user.posts.unscope(where: :status).update_all(
        title: Post::ANONYMIZED_TITLE,
        body: "",
        status: "anonymized"
      )

      # 2. 投稿の画像を削除
      @user.posts.unscope(where: :status).with_attached_thumbnail.each do |post|
        post.thumbnail.purge if post.thumbnail.attached?
      end

      # 3. アバターを削除
      @user.avatar.purge if @user.avatar.attached?

      # 4. ユーザー情報を匿名化
      @user.update!(
        username: "deleted_user_#{@user.id}",
        display_name: User::ANONYMIZED_DISPLAY_NAME,
        email: "deleted_#{@user.id}@deleted.coconikki.com",
        bio: nil,
        google_uid: nil,
        avatar_url: nil,
        deleted_at: Time.current
      )
    end

    # セッションをクリア
    reset_session

    redirect_to root_path, notice: "退会が完了しました。ご利用ありがとうございました。"
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
