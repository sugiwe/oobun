class CreateLoginInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :login_invitations do |t|
      t.string :token, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.string :note

      t.timestamps
    end
    add_index :login_invitations, :token, unique: true
  end
end
