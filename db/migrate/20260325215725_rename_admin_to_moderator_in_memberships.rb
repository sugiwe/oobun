class RenameAdminToModeratorInMemberships < ActiveRecord::Migration[8.1]
  def up
    # 既存の "admin" を "moderator" に変更
    Membership.where(role: "admin").update_all(role: "moderator")
  end

  def down
    # "moderator" を "admin" に戻す
    Membership.where(role: "moderator").update_all(role: "admin")
  end
end
