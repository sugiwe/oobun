class ChangeDigestTimeToString < ActiveRecord::Migration[8.1]
  def up
    # 既存データを一旦バックアップとして読み取り、文字列型に変換
    # time型は "HH:MM:SS" 形式で保存
    change_column :notification_settings, :digest_time, :string, default: "08:00", null: false

    # 既存データを "08:00" に統一（17:00 JSTは実質08:00 UTCなので、意図した08:00 JSTに修正）
    NotificationSetting.update_all(digest_time: "08:00")
  end

  def down
    change_column :notification_settings, :digest_time, :time, default: "08:00:00", null: false
  end
end
