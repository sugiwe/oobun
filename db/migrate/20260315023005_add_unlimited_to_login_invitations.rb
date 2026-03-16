class AddUnlimitedToLoginInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :login_invitations, :unlimited, :boolean, default: false, null: false
  end
end
