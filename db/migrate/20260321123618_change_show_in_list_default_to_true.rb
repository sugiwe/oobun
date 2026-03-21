class ChangeShowInListDefaultToTrue < ActiveRecord::Migration[8.1]
  def change
    # デフォルト値をtrueに変更
    change_column_default :threads, :show_in_list, from: false, to: true

    # 既存のレコードもtrueに更新（一覧に表示されるようにする）
    reversible do |dir|
      dir.up do
        execute "UPDATE threads SET show_in_list = true WHERE show_in_list = false"
      end
      # rollback時は何もしない（既存データは維持）
    end
  end
end
