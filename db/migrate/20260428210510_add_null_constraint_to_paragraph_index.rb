class AddNullConstraintToParagraphIndex < ActiveRecord::Migration[8.1]
  def up
    # paragraph_indexがnullの既存レコードに0をセット（段落インデックスのデフォルト）
    # 本番環境では既存データがない想定だが、開発環境での安全性のため
    Annotation.where(paragraph_index: nil).update_all(paragraph_index: 0)

    # paragraph_indexは必須フィールドであるため、データベースレベルでもnull制約を追加
    # アプリケーションレベル（presence: true）とDB制約の両方で整合性を保証
    change_column_null :annotations, :paragraph_index, false
  end

  def down
    # null制約を削除（ロールバック時）
    change_column_null :annotations, :paragraph_index, true
  end
end
