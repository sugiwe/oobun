class AddIsSampleToCorrespondenceThreads < ActiveRecord::Migration[8.1]
  def change
    add_column :threads, :is_sample, :boolean, default: false, null: false
    add_index :threads, :is_sample
  end
end
