class BackfillPublishedAtForPosts < ActiveRecord::Migration[8.1]
  def up
    # published と anonymized の投稿に対して、published_at が nil の場合は created_at で埋める
    execute <<-SQL
      UPDATE posts
      SET published_at = created_at
      WHERE status IN ('published', 'anonymized')
        AND published_at IS NULL
    SQL
  end

  def down
    # ロールバック時は何もしない（published_at をクリアすると情報が失われる）
    # 必要に応じて手動で対応
  end
end
