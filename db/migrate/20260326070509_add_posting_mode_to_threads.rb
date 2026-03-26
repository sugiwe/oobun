class AddPostingModeToThreads < ActiveRecord::Migration[8.1]
  def change
    add_column :threads, :posting_mode, :string, default: "relay", null: false
  end
end
