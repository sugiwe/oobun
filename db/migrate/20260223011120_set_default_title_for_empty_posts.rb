class SetDefaultTitleForEmptyPosts < ActiveRecord::Migration[8.1]
  def up
    # タイトルが空の既存投稿に「無題」を設定
    Post.where("title IS NULL OR title = ''").update_all(title: "無題")
  end

  def down
    # ロールバック時は何もしない（元の空文字列に戻すのは適切でない）
  end
end
