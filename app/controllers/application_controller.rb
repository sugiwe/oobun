class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :require_login
  before_action :track_user_activity

  helper_method :current_user, :logged_in?, :unread_notifications_count

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def unread_notifications_count
    return 0 unless logged_in?
    @unread_notifications_count ||= current_user.notifications.unread.count
  end

  def require_login
    unless logged_in?
      redirect_to login_path, alert: "ログインしてください"
    end
  end

  # ログイン中のユーザーの最終アクティビティ日時を更新
  # パフォーマンスのため、前回の更新から5分以上経過している場合のみ更新
  def track_user_activity
    return unless logged_in?
    return if current_user.last_activity_at.present? && current_user.last_activity_at > 5.minutes.ago

    current_user.update_column(:last_activity_at, Time.current)
  end

  # 月間枠をインクリメント（招待経由でない場合のみ）
  def increment_monthly_quota_if_needed(user)
    # 招待経由の場合はカウント不要
    return if session[:invitation_token].present?

    # 月間枠をインクリメント
    MonthlySignupQuota.current_month.increment_signups!
    Rails.logger.info "Monthly signup quota incremented for user #{user.email}"
  rescue StandardError => e
    # エラーがあってもユーザー登録は継続（ログのみ）
    Rails.logger.error "Failed to increment monthly quota: #{e.message}"
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

  # 招待トークンの処理: Membership作成
  # 戻り値: 参加した交換日記のslug（成功時）またはnil（失敗時）
  def process_invitation(user, invitation)
    # 招待が有効か確認
    return nil unless invitation&.usable?

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
