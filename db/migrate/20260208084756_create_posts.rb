class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.references :thread, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.datetime :published_at

      t.timestamps
    end
    add_index :posts, :published_at
    add_index :posts, [:thread_id, :created_at]
  end
end
