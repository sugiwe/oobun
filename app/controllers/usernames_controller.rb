class UsernamesController < ApplicationController
  skip_before_action :require_login
  before_action :require_pending_payload

  def new
  end

  def create
    payload = session[:pending_google_payload]

    user = User.find_or_initialize_by(google_uid: payload["sub"])
    user.assign_attributes(
      email:        payload["email"],
      display_name: payload["name"],
      avatar_url:   payload["picture"],
      username:     params[:username]
    )

    if user.save
      session.delete(:pending_google_payload)
      session[:user_id] = user.id
      process_login_invitation_if_present(user)  # ログイン許可招待処理
      thread_slug = process_invitation_if_present(user)
      if thread_slug
        redirect_to thread_path(thread_slug), notice: "ようこそ！アカウントを作成して交換日記に参加しました"
      else
        redirect_to root_path, notice: "ようこそ！アカウントを作成しました"
      end
    else
      @user = user
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_pending_payload
    unless session[:pending_google_payload].present?
      redirect_to login_path
    end
  end
end
