class RemoveOffsetFieldsFromAnnotations < ActiveRecord::Migration[8.1]
  def change
    # start_offset と end_offset は文字単位の範囲指定用だったが、
    # 現在は paragraph_index による段落単位の付箋に変更されたため不要
    # 既存データでも常に start_offset=0, end_offset=段落文字数 の固定値のみ使用
    remove_column :annotations, :start_offset, :integer, null: false
    remove_column :annotations, :end_offset, :integer, null: false
  end
end
