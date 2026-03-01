class AddStatusToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :status, :string, default: "published", null: false
    add_index :posts, :status
    add_index :posts, [ :thread_id, :status ]

    # 1ユーザーにつき1スレッドあたり1下書きのみ（部分インデックス）
    add_index :posts, [ :user_id, :thread_id ],
              unique: true,
              where: "status = 'draft'",
              name: "index_posts_on_user_thread_draft_uniqueness"
  end
end
