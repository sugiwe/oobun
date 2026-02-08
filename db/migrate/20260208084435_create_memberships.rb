class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :thread, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :role, null: false, default: 'writer'

      t.timestamps
    end
    add_index :memberships, [:thread_id, :position], unique: true
    add_index :memberships, [:user_id, :thread_id], unique: true
  end
end
