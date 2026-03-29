class AddLastDigestSentAtToNotificationSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :notification_settings, :last_digest_sent_at, :datetime
  end
end
