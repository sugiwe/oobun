class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :thread, null: false, foreign_key: true

      t.timestamps
    end
    add_index :subscriptions, [ :user_id, :thread_id ], unique: true
  end
end
