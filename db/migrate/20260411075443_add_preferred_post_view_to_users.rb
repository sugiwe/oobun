class AddPreferredPostViewToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :preferred_post_view, :string, default: "markdown", null: false
  end
end
