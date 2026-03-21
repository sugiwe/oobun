class CreateNotificationSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_settings do |t|
      t.references :user, null: false, foreign_key: true

      # 通知タイプごとのON/OFF（デフォルト: 有効）
      t.boolean :notify_member_posts, default: true
      t.boolean :notify_subscription_posts, default: true
      t.boolean :notify_invitations, default: true

      # Webhook設定
      t.string :discord_webhook_url
      t.string :slack_webhook_url
      t.boolean :use_discord, default: false
      t.boolean :use_slack, default: false

      t.timestamps
    end
  end
end
