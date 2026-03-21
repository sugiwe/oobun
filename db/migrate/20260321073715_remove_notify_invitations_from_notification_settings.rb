class RemoveNotifyInvitationsFromNotificationSettings < ActiveRecord::Migration[8.1]
  def change
    remove_column :notification_settings, :notify_invitations, :boolean
  end
end
