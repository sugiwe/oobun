class AddSlugToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :slug, :string
    # 同じスレッド内でslugの重複を防ぐためのユニークインデックス
    add_index :posts, [ :thread_id, :slug ], unique: true
  end
end
