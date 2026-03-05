class AddPublishedToThreads < ActiveRecord::Migration[8.1]
  def change
    add_column :threads, :published, :boolean, default: false, null: false
    add_column :threads, :published_at, :datetime

    # 既存のスレッドを公開済みに設定（投稿があるスレッドのみ）
    reversible do |dir|
      dir.up do
        # 投稿が1件以上あるスレッドを公開済みに
        execute <<-SQL
          UPDATE threads
          SET published = true, published_at = NOW()
          WHERE id IN (
            SELECT DISTINCT thread_id
            FROM posts
            WHERE status = 'published'
          )
        SQL
      end
    end
  end
end
