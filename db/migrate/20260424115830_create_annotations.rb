class CreateAnnotations < ActiveRecord::Migration[8.1]
  def change
    create_table :annotations do |t|
      t.references :post, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :start_offset, null: false
      t.integer :end_offset, null: false
      t.text :selected_text, null: false
      t.text :body, null: false
      t.string :visibility, null: false, default: "self_only"

      t.timestamps
    end

    add_index :annotations, [ :post_id, :created_at ]
    add_index :annotations, [ :user_id, :created_at ]
  end
end
