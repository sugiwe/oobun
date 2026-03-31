class ChangeDigestTimeToString < ActiveRecord::Migration[8.1]
  def up
    # 既存データを一旦バックアップとして読み取り、文字列型に変換
    # time型は "HH:MM:SS" 形式で保存
    change_column :notification_settings, :digest_time, :string, default: "08:00", null: false

    # 既存データを "08:00" に統一（17:00 JSTは実質08:00 UTCなので、意図した08:00 JSTに修正）
    # マイグレーション内でモデルを使わず、SQLで直接更新
    execute "UPDATE notification_settings SET digest_time = '08:00'"
  end

  def down
    # string型からtime型への変換にはUSING句が必要
    # デフォルト値を先に削除してから型変換
    execute "ALTER TABLE notification_settings ALTER COLUMN digest_time DROP DEFAULT"
    execute "ALTER TABLE notification_settings ALTER COLUMN digest_time TYPE time USING (digest_time || ':00')::time"
    execute "ALTER TABLE notification_settings ALTER COLUMN digest_time SET DEFAULT '08:00:00'::time"
    execute "ALTER TABLE notification_settings ALTER COLUMN digest_time SET NOT NULL"
  end
end
