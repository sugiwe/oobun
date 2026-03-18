class AddNoindexToThreads < ActiveRecord::Migration[8.1]
  def change
    add_column :threads, :noindex, :boolean, default: false, null: false
  end
end
