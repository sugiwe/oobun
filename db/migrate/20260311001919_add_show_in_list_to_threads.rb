class AddShowInListToThreads < ActiveRecord::Migration[8.1]
  def change
    add_column :threads, :show_in_list, :boolean, default: false, null: false
  end
end
