class LoginInvitationsController < ApplicationController
  skip_before_action :require_login
  before_action :set_login_invitation
  before_action :check_invitation_status

  # GET /login-invite/:token
  # ログイン許可招待を受け取った人が確認画面を見る
  def show
    # 招待トークンをセッションに保存（ログイン許可に使用）
    session[:login_invitation_token] = @login_invitation.token
    # 未ログイン時も招待画面を表示（show.html.slimで分岐）
  end

  private

  def set_login_invitation
    @login_invitation = LoginInvitation.includes(:created_by).find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "招待URLが見つかりません"
  end

  def check_invitation_status
    unless @login_invitation.usable?
      if @login_invitation.expired?
        redirect_to root_path, alert: "この招待URLは有効期限切れです"
      elsif @login_invitation.used? && !@login_invitation.unlimited?
        redirect_to root_path, alert: "この招待はすでに使用済みです"
      end
    end
  end
end
