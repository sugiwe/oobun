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
    # draft → url_only (以前のモデルで有効な非公開値)
    # free → public
    # paid → paid
    execute <<-SQL
      UPDATE threads
      SET visibility = CASE
        WHEN status = 'paid' THEN 'paid'
        WHEN status = 'free' THEN 'public'
        ELSE 'url_only'
      END
    SQL

    remove_column :threads, :status
  end
end
