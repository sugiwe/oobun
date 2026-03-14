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

      # 招待トークンがあれば処理（AllowedUser追加 & Membership作成）
      if session[:invitation_token]
        process_invitation(user, session[:invitation_token])
        session.delete(:invitation_token)
      end

      redirect_to root_path, notice: "ようこそ！アカウントを作成しました"
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
