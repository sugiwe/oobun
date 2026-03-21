class NotificationsController < ApplicationController
  before_action :require_login

  def index
    @notifications = current_user.notifications
                                  .recent
                                  .page(params[:page])
                                  .per(30)
  end

  def mark_as_read
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_as_read!

    redirect_to notification_link(@notification), status: :see_other, allow_other_host: false
  end

  private

  def notification_link(notification)
    case notification.action
    when "new_post"
      # 投稿詳細ページへ遷移
      if notification.notifiable.is_a?(Post)
        "/#{notification.params['thread_slug']}/posts/#{notification.notifiable.id}"
      else
        # 投稿が削除されている場合はスレッド詳細へ
        "/#{notification.params['thread_slug']}"
      end
    else
      notifications_path
    end
  end
end
