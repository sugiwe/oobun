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

  def can_view_thread?(thread)
    # Phase 1: public のみ閲覧可能
    return true if thread.visibility == "public"

    # Phase 3 で追加予定の visibility:
    # - url_only: URL を知っていれば誰でも閲覧可能
    #   return true if thread.visibility == "url_only"
    #
    # - followers_only / paid: メンバーのみ閲覧可能
    #   return true if logged_in? && thread.memberships.exists?(user: current_user)

    false
  end
end
