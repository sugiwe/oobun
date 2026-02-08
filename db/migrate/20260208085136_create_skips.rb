class CreateSkips < ActiveRecord::Migration[8.1]
  def change
    create_table :skips do |t|
      t.references :user, null: false, foreign_key: true
      t.references :thread, null: false, foreign_key: true

      t.timestamps
    end
    add_index :skips, [:thread_id, :created_at]
  end
end
