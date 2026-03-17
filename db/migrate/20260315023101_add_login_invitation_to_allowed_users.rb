class AddLoginInvitationToAllowedUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :allowed_users, :login_invitation, null: true, foreign_key: true
  end
end
