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

      expect(page).to have_checked_field("ダイジェスト配信")
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
      choose "ダイジェスト配信"

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

      # 初期状態ではダイジェスト配信が選択されており、時刻選択が表示されている
      expect(page).to have_select("notification_setting[digest_time]", visible: :visible)

      # メール通知なしを選択 - ラジオボタンを直接クリック
      find("input[value='off']").click

      # JavaScriptの実行を待つために少し待機
      sleep 0.5

      # 設定項目が非表示（JavaScriptで制御）
      expect(page).to have_no_selector("select[name='notification_setting[digest_time]']", visible: :visible)
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

  describe "テスト通知の送信" do
    context "即時配信モード" do
      before do
        user.create_notification_setting(
          email_mode: :realtime,
          digest_time: Time.zone.parse("08:00:00"),
          email_count_this_month: 0,
          email_count_reset_at: Date.current.beginning_of_month
        )
      end

      it "テスト通知を送信すると、アプリ内通知とメール通知の両方が作成される" do
        visit settings_notifications_path

        # 即時配信モードの案内が表示される
        expect(page).to have_content("テスト通知について（即時配信モード）")
        expect(page).to have_content("残り配信数が1つ減ります")

        # テスト通知を送信（ジョブを同期実行してテストを簡潔にする）
        perform_enqueued_jobs do
          expect {
            click_button "テスト通知を送る"
          }.to change { user.notifications.count }.by(1)
        end

        expect(page).to have_content("テスト通知を送信しました")

        # 通知が作成されたことを確認
        notification = user.notifications.last
        expect(notification.action).to eq("test_notification")
        expect(notification.params["message"]).to be_present

        # 残数が1減ることを確認（ジョブが同期実行されたので即座に確認可能）
        user.notification_setting.reload
        expect(user.notification_setting.remaining_emails_this_month).to eq(99)
      end
    end

    context "ダイジェスト配信モード" do
      before do
        user.create_notification_setting(
          email_mode: :digest,
          digest_time: Time.zone.parse("08:00:00")
        )
      end

      it "テスト通知を送信すると、アプリ内通知のみ作成される" do
        visit settings_notifications_path

        # ダイジェスト配信モードの案内が表示される
        expect(page).to have_content("テスト通知について（ダイジェスト配信モード）")
        expect(page).to have_content("テスト通知はアプリ内通知のみ送信されます")

        # テスト通知を送信
        expect {
          click_button "テスト通知を送る"
        }.to change { user.notifications.count }.by(1)

        expect(page).to have_content("テスト通知を送信しました")

        # 通知が作成されたことを確認
        notification = user.notifications.last
        expect(notification.action).to eq("test_notification")
      end
    end

    context "メール通知なしモード" do
      before do
        user.create_notification_setting(
          email_mode: :off,
          digest_time: Time.zone.parse("08:00:00")
        )
      end

      it "テスト通知を送信すると、アプリ内通知のみ作成される" do
        visit settings_notifications_path

        # メール通知なしモードの案内が表示される
        expect(page).to have_content("テスト通知について（メール通知なし）")
        expect(page).to have_content("テスト通知はアプリ内通知のみ送信されます")

        # テスト通知を送信
        expect {
          click_button "テスト通知を送る"
        }.to change { user.notifications.count }.by(1)

        expect(page).to have_content("テスト通知を送信しました")

        # 通知が作成されたことを確認
        notification = user.notifications.last
        expect(notification.action).to eq("test_notification")
      end
    end
  end
end
