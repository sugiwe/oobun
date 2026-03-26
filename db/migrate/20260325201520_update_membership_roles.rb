class UpdateMembershipRoles < ActiveRecord::Migration[8.1]
  def up
    # 既存の "writer" を "member" に変更
    Membership.where(role: "writer").update_all(role: "member")

    # position 1 (作成者) を "owner" に昇格
    Membership.where(position: 1).update_all(role: "owner")
  end

  def down
    # すべてのroleを "writer" に戻す
    Membership.update_all(role: "writer")
  end
end
