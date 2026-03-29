class AddIndexToNotificationSettings < ActiveRecord::Migration[8.1]
  def change
    add_index :notification_settings, [ :email_mode, :digest_time ]
  end
end
