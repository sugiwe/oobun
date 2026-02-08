class CreateThreads < ActiveRecord::Migration[8.1]
  def change
    create_table :threads do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description
      t.string :visibility, null: false, default: 'public'
      t.boolean :turn_based, null: false, default: true
      t.integer :last_post_user_id
      t.datetime :last_posted_at

      t.timestamps
    end
    add_index :threads, :slug, unique: true
    add_index :threads, :last_posted_at
  end
end
