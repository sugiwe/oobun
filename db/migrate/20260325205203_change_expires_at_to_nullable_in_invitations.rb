class ChangeExpiresAtToNullableInInvitations < ActiveRecord::Migration[8.1]
  def up
    change_column_null :invitations, :expires_at, true
  end

  def down
    # expires_at を NOT NULL に戻す前に、NULL の値にデフォルト値を設定
    Invitation.where(expires_at: nil).update_all(expires_at: 7.days.from_now)
    change_column_null :invitations, :expires_at, false
  end
end
