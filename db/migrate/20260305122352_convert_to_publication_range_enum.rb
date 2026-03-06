class ConvertToPublicationRangeEnum < ActiveRecord::Migration[8.1]
  def up
    # 新しい status カラムを追加
    add_column :threads, :status, :string, default: "draft", null: false

    # 既存データを変換
    # visibility = "public" → status = "free" (無料公開)
    # それ以外           → status = "draft" (下書き)
    execute <<-SQL
      UPDATE threads
      SET status = CASE
        WHEN visibility = 'public' THEN 'free'
        ELSE 'draft'
      END
    SQL

    # 古いカラムを削除
    remove_column :threads, :visibility
  end

  def down
    # ロールバック時の処理
    add_column :threads, :visibility, :string, default: "public", null: false

    # データを戻す
    execute <<-SQL
      UPDATE threads
      SET visibility = CASE
        WHEN status IN ('free', 'paid') THEN 'public'
        ELSE 'private'
      END
    SQL

    remove_column :threads, :status
  end
end
