class AddContactedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :contacted, :boolean, default: false, null: false
  end
end
