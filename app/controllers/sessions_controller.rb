class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
    redirect_to root_path if logged_in?
  end

  def create
    # Google の CSRF トークン検証（ダブルサブミットクッキーパターン）
    unless valid_google_csrf_token?
      redirect_to login_path, alert: "不正なリクエストです"
      return
    end

    payload = verify_google_id_token(params[:credential])
    unless payload
      redirect_to login_path, alert: "Google 認証に失敗しました"
      return
    end

    user = User.find_or_initialize_from_google(payload)

    if user.new_record? || user.username.blank?
      # 新規ユーザー: username 設定画面へ
      session[:pending_google_payload] = payload.slice("sub", "email", "name", "picture")
      redirect_to new_username_path
    else
      session[:user_id] = user.id
      redirect_to root_path, notice: "ログインしました"
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: "ログアウトしました"
  end

  private

  def valid_google_csrf_token?
    cookies["g_csrf_token"].present? &&
      params["g_csrf_token"].present? &&
      cookies["g_csrf_token"] == params["g_csrf_token"]
  end

  def verify_google_id_token(credential)
    Google::Auth::IDTokens.verify_oidc(credential, aud: GOOGLE_CLIENT_ID)
  rescue Google::Auth::IDTokens::VerificationError => e
    Rails.logger.warn "Google ID token verification failed: #{e.message}"
    nil
  end
end
