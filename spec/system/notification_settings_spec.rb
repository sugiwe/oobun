require "rails_helper"

RSpec.describe "NotificationSettings", type: :system do
  let(:user) { create(:user) }

  before do
    # ログイン処理（Sorceryの場合）
    login_as(user)
  end

  describe "通知設定画面" do
    it "通知設定ページにアクセスできる" do
      visit settings_notifications_path

      expect(page).to have_content("通知設定")
      expect(page).to have_content("メール通知")
    end

    it "デフォルトでダイジェスト配信が選択されている" do
      visit settings_notifications_path

      expect(page).to have_checked_field("ダイジェスト配信（推奨）")
      expect(page).to have_select("notification_setting[digest_time]")
    end
  end

  describe "メール配信モードの切り替え", js: true do
    before do
      # 通知設定を作成
      user.create_notification_setting(
        email_mode: :digest,
        digest_time: Time.zone.parse("08:00:00")
      )
    end

    it "ダイジェスト配信を選択すると配信時刻の選択が表示される" do
      visit settings_notifications_path

      # ダイジェストを選択
      choose "ダイジェスト配信（推奨）"

      # 時刻選択が表示される
      expect(page).to have_select("notification_setting[digest_time]")
    end

    it "即時配信を選択すると残り配信数が表示される" do
      visit settings_notifications_path

      # 即時配信を選択
      choose "即時配信"

      # 残り配信数が表示される（JavaScriptで表示切り替え）
      expect(page).to have_content("今月の残り:")
    end

    it "メール通知なしを選択すると設定項目が非表示になる" do
      visit settings_notifications_path

      # メール通知なしを選択
      choose "メール通知なし"

      # 設定項目が非表示（JavaScriptで制御）
      expect(page).not_to have_select("notification_setting[digest_time]")
    end
  end

  describe "ダイジェスト配信時刻の変更" do
    before do
      user.create_notification_setting(
        email_mode: :digest,
        digest_time: Time.zone.parse("08:00:00")
      )
    end

    it "配信時刻を変更して保存できる" do
      visit settings_notifications_path

      # 時刻を変更
      select "18:00", from: "notification_setting[digest_time]"

      click_button "保存"

      expect(page).to have_content("通知設定を保存しました")

      # 設定が保存されたことを確認
      user.notification_setting.reload
      expect(user.notification_setting.digest_time.hour).to eq(18)
    end
  end

  describe "即時配信への切り替え" do
    before do
      user.create_notification_setting(
        email_mode: :digest,
        digest_time: Time.zone.parse("08:00:00")
      )
    end

    it "即時配信に切り替えて保存できる" do
      visit settings_notifications_path

      # 即時配信を選択
      choose "即時配信"

      click_button "保存"

      expect(page).to have_content("通知設定を保存しました")

      # 設定が保存されたことを確認
      user.notification_setting.reload
      expect(user.notification_setting.email_mode_realtime?).to be true
      expect(user.notification_setting.remaining_emails_this_month).to eq(100)
    end
  end

  describe "メール通知なしへの変更" do
    before do
      user.create_notification_setting(
        email_mode: :digest,
        digest_time: Time.zone.parse("08:00:00")
      )
    end

    it "メール通知なしに変更して保存できる" do
      visit settings_notifications_path

      # メール通知なしを選択
      choose "メール通知なし"

      click_button "保存"

      expect(page).to have_content("通知設定を保存しました")

      # 設定が保存されたことを確認
      user.notification_setting.reload
      expect(user.notification_setting.email_mode_off?).to be true
    end
  end
end
