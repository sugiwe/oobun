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

  private

  # 招待トークンがセッションにあれば処理
  def process_invitation_if_present(user)
    return unless session[:invitation_token]

    process_invitation(user, session[:invitation_token])
    session.delete(:invitation_token)
  end

  # 招待トークンの処理: AllowedUserに追加 & Membership作成
  def process_invitation(user, token)
    invitation = Invitation.find_by(token: token)

    # 招待が有効か確認
    return unless invitation && !invitation.accepted? && !invitation.expired?

    # AllowedUserテーブルに追加（まだ存在しない場合）
    # 招待による登録なので added_by_admin = false
    AllowedUser.find_or_create_by!(email: user.email.downcase.strip) do |allowed_user|
      allowed_user.invited_by = invitation.invited_by
      allowed_user.added_by_admin = false
      allowed_user.note = "招待リンクから登録 (#{invitation.invited_by&.display_name})"
    end

    # 招待を受け入れる（Membershipを作成）
    # ユーザーレコードをロックして競合状態を防ぐ
    user.with_lock do
      if user.can_join_thread? && !invitation.thread.memberships.exists?(user: user)
        invitation.accept!(user)
        Rails.logger.info "User #{user.email} accepted invitation #{invitation.token}"
      else
        Rails.logger.warn "User #{user.email} cannot join thread (limit reached or already member)"
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Failed to process invitation: #{e.message}"
  end
end
