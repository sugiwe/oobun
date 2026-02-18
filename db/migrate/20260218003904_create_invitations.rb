class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.references :thread, null: false, foreign_key: { to_table: :threads }
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at

      t.timestamps
    end
    add_index :invitations, :token, unique: true
  end
end
