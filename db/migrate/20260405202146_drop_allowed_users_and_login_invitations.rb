class DropAllowedUsersAndLoginInvitations < ActiveRecord::Migration[8.1]
  def up
    drop_table :allowed_users
    drop_table :login_invitations
  end

  def down
    # 逆方向のマイグレーションは提供しない（削除したテーブルは復元不可）
    raise ActiveRecord::IrreversibleMigration
  end
end
