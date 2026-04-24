class AddParagraphLevelFieldsToAnnotations < ActiveRecord::Migration[8.1]
  def change
    add_column :annotations, :paragraph_index, :integer
    add_column :annotations, :invalidated_at, :datetime
    add_column :annotations, :invalidation_reason, :string
  end
end
