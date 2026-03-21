class Settings::NotificationsController < ApplicationController
  before_action :require_login

  def show
    @notification_setting = current_user.notification_setting || current_user.build_notification_setting
  end

  def update
    @notification_setting = current_user.notification_setting || current_user.create_notification_setting!

    if @notification_setting.update(notification_setting_params)
      respond_to do |format|
        format.html { redirect_to settings_notifications_path, notice: "通知設定を保存しました" }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "notification_setting_form",
            partial: "settings/notifications/form",
            locals: { notification_setting: @notification_setting }
          )
        end
      end
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def notification_setting_params
    params.require(:notification_setting).permit(
      :notify_member_posts,
      :notify_subscription_posts
    )
  end
end
