class RenamePostStatusDeletedToAnonymized < ActiveRecord::Migration[8.1]
  def up
    # 既存の 'deleted' ステータスを 'anonymized' に変更
    Post.unscope(where: :status).where(status: "deleted").update_all(status: "anonymized")
  end

  def down
    # ロールバック時は逆の操作
    Post.unscope(where: :status).where(status: "anonymized").update_all(status: "deleted")
  end
end
