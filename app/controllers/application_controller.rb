class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :require_login

  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    unless logged_in?
      redirect_to login_path, alert: "ログインしてください"
    end
  end

  # ログイン許可招待トークンがセッションにあれば処理してAllowedUserに追加
  def process_login_invitation_if_present(user)
    return unless session[:login_invitation_token]

    login_invitation = LoginInvitation.find_by(token: session[:login_invitation_token])
    if login_invitation&.usable?
      AllowedUser.find_or_create_by!(email: user.email.downcase.strip) do |allowed_user|
        allowed_user.invited_by = login_invitation.created_by
        allowed_user.login_invitation = login_invitation  # どの招待リンクから登録したかを記録
        allowed_user.added_by_admin = true  # 管理者発行なのでtrue
        allowed_user.note = "管理者招待リンクから登録 (#{login_invitation.created_by.display_name})"
      end
      login_invitation.mark_as_used!
      session.delete(:login_invitation_token)
      Rails.logger.info "User #{user.email} used login invitation #{login_invitation.token}"
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Failed to process login invitation: #{e.message}"
  end

  # 招待トークンがセッションにあれば処理して交換日記ページへのリダイレクトURLを返す
  def process_invitation_if_present(user, invitation = nil)
    return nil unless session[:invitation_token]

    # 既にキャッシュされた招待がある場合はそれを使用、なければ取得
    invitation ||= Invitation.find_by(token: session[:invitation_token])
    thread_slug = process_invitation(user, invitation)
    session.delete(:invitation_token)
    thread_slug
  end

  # 招待トークンの処理: AllowedUserに追加 & Membership作成
  # 戻り値: 参加した交換日記のslug（成功時）またはnil（失敗時）
  def process_invitation(user, invitation)
    # 招待が有効か確認
    return nil unless invitation&.usable?

    # AllowedUserテーブルに追加（まだ存在しない場合）
    # 招待による登録なので added_by_admin = false
    AllowedUser.find_or_create_by!(email: user.email.downcase.strip) do |allowed_user|
      allowed_user.invited_by = invitation.invited_by
      allowed_user.added_by_admin = false
      allowed_user.note = "招待リンクから登録 (#{invitation.invited_by&.display_name})"
    end

    # 招待を受け入れる（Membershipを作成）
    # ユーザーレコードをロックして競合状態を防ぐ
    thread_slug = nil
    user.with_lock do
      if user.can_join_thread? && !invitation.thread.memberships.exists?(user: user)
        invitation.accept!(user)
        thread_slug = invitation.thread.slug
        Rails.logger.info "User #{user.email} accepted invitation #{invitation.token}"
      else
        Rails.logger.warn "User #{user.email} cannot join thread (limit reached or already member)"
      end
    end
    thread_slug
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Failed to process invitation: #{e.message}"
    nil
  end
end
