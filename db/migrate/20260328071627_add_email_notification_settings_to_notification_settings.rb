class AddEmailNotificationSettingsToNotificationSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :notification_settings, :email_mode, :string, default: "digest", null: false
    add_column :notification_settings, :digest_time, :time, default: "08:00:00", null: false
    add_column :notification_settings, :email_count_this_month, :integer, default: 0, null: false
    add_column :notification_settings, :email_count_reset_at, :date
  end
end
