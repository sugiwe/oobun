class CreateAllowedUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :allowed_users do |t|
      t.string :email, null: false
      t.text :note
      t.boolean :added_by_admin, default: false, null: false
      t.boolean :contacted, default: false, null: false
      t.references :invited_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :allowed_users, :email, unique: true
    add_index :allowed_users, :added_by_admin
    add_index :allowed_users, :contacted
  end
end
