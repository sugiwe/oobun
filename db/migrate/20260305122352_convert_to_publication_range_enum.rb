class ConvertToPublicationRangeEnum < ActiveRecord::Migration[8.1]
  def up
    # 新しい status カラムを追加
    add_column :threads, :status, :string, default: "draft", null: false

    # 既存データを変換
    # published = true  → status = "free" (無料公開)
    # published = false → status = "draft" (下書き)
    execute <<-SQL
      UPDATE threads
      SET status = CASE
        WHEN published = true THEN 'free'
        ELSE 'draft'
      END
    SQL

    # 古いカラムを削除
    remove_column :threads, :published
    remove_column :threads, :published_at
    remove_column :threads, :visibility
  end

  def down
    # ロールバック時の処理
    add_column :threads, :published, :boolean, default: false, null: false
    add_column :threads, :published_at, :datetime
    add_column :threads, :visibility, :string, default: "public", null: false

    # データを戻す
    execute <<-SQL
      UPDATE threads
      SET published = CASE
        WHEN status IN ('free', 'paid') THEN true
        ELSE false
      END,
      visibility = CASE
        WHEN status = 'paid' THEN 'paid'
        ELSE 'public'
      END
    SQL

    remove_column :threads, :status
  end
end
