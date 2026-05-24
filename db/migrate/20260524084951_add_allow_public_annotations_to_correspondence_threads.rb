class AddAllowPublicAnnotationsToCorrespondenceThreads < ActiveRecord::Migration[8.1]
  def change
    add_column :threads, :allow_public_annotations, :boolean, default: true, null: false
  end
end
