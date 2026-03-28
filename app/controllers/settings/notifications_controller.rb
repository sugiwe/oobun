class Settings::NotificationsController < ApplicationController
  before_action :require_login
  before_action :ensure_notification_setting, only: [ :show, :update ]

  def show
    # ensure_notification_settingで作成された場合、@setting_just_createdフラグが立つ
    if @setting_just_created
      flash.now[:notice] = "通知設定を初期化しました。デフォルトで通知はONになっています。"
    end
  end

  def update
    # digest_timeが"HH:MM:SS"形式の文字列で来た場合、Time型に変換
    params_hash = notification_setting_params.to_h
    if params_hash[:digest_time].is_a?(String) && params_hash[:digest_time].match?(/\A\d{2}:\d{2}:\d{2}\z/)
      hour = params_hash[:digest_time].split(":").first.to_i
      params_hash[:digest_time] = Time.zone.parse("#{hour}:00")
    end

    if @notification_setting.update(params_hash)
      redirect_to settings_notifications_path, notice: "通知設定を保存しました"
    else
      render :show, status: :unprocessable_entity
    end
  end

  def send_test
    current_user.notifications.create!(
      actor: current_user,
      notifiable: current_user,
      action: :test_notification,
      params: {
        message: "これはテスト通知です。実際の通知はこのように表示されます。"
      }
    )
    redirect_to settings_notifications_path, notice: "テスト通知を送信しました。通知一覧を確認してください。"
  end

  private

  def ensure_notification_setting
    @notification_setting = current_user.notification_setting

    unless @notification_setting
      @notification_setting = current_user.create_default_notification_setting
      @setting_just_created = true
    end
  end

  def notification_setting_params
    params.require(:notification_setting).permit(
      :notify_member_posts,
      :notify_subscription_posts,
      :email_mode,
      :digest_time
    )
  end
end
