class BackfillNotificationSettingsForExistingUsers < ActiveRecord::Migration[8.1]
  def up
    # notification_settingsを持たない既存ユーザーに対して、デフォルト設定を作成
    # (新規ユーザーはafter_createコールバックで自動作成されるため、既存ユーザーのみ対象)
    User.find_each do |user|
      next if user.notification_setting.present?

      NotificationSetting.create!(
        user: user,
        notify_member_posts: true,
        notify_subscription_posts: true,
        use_discord: false,
        use_slack: false
      )
    end
  end

  def down
    # rollback時は何もしない（手動で作成された設定と区別できないため）
  end
end
