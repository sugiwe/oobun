require "rails_helper"

RSpec.describe NotificationSetting, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "validations" do
    describe "discord_webhook_url" do
      it "正しいHTTPS URLは有効" do
        setting = build(:notification_setting, discord_webhook_url: "https://discord.com/api/webhooks/123/abc")
        expect(setting).to be_valid
      end

      it "HTTP URLは無効" do
        setting = build(:notification_setting, discord_webhook_url: "http://discord.com/api/webhooks/123/abc")
        expect(setting).not_to be_valid
      end

      it "空白は有効" do
        setting = build(:notification_setting, discord_webhook_url: "")
        expect(setting).to be_valid
      end

      it "nilは有効" do
        setting = build(:notification_setting, discord_webhook_url: nil)
        expect(setting).to be_valid
      end
    end

    describe "slack_webhook_url" do
      it "正しいHTTPS URLは有効" do
        setting = build(:notification_setting, slack_webhook_url: "https://hooks.slack.com/services/T00/B00/XXX")
        expect(setting).to be_valid
      end

      it "HTTP URLは無効" do
        setting = build(:notification_setting, slack_webhook_url: "http://hooks.slack.com/services/T00/B00/XXX")
        expect(setting).not_to be_valid
      end

      it "空白は有効" do
        setting = build(:notification_setting, slack_webhook_url: "")
        expect(setting).to be_valid
      end

      it "nilは有効" do
        setting = build(:notification_setting, slack_webhook_url: nil)
        expect(setting).to be_valid
      end
    end
  end

  describe "callbacks" do
    describe "#disable_webhooks_if_urls_blank" do
      context "Discord webhook URLが空白の場合" do
        it "use_discordをfalseにする" do
          setting = create(:notification_setting, discord_webhook_url: "https://discord.com/webhook", use_discord: true)
          setting.update(discord_webhook_url: "")
          expect(setting.use_discord).to be false
        end
      end

      context "Slack webhook URLが空白の場合" do
        it "use_slackをfalseにする" do
          setting = create(:notification_setting, slack_webhook_url: "https://hooks.slack.com/webhook", use_slack: true)
          setting.update(slack_webhook_url: "")
          expect(setting.use_slack).to be false
        end
      end

      context "webhook URLが設定されている場合" do
        it "use_discord/use_slackはそのまま" do
          setting = create(:notification_setting, discord_webhook_url: "https://discord.com/webhook", use_discord: true)
          setting.update(notify_member_posts: false)
          expect(setting.use_discord).to be true
        end
      end
    end
  end

  describe "デフォルト値" do
    let(:setting) { create(:notification_setting) }

    it "notify_member_postsはtrueがデフォルト" do
      expect(setting.notify_member_posts).to be true
    end

    it "notify_subscription_postsはtrueがデフォルト" do
      expect(setting.notify_subscription_posts).to be true
    end

    it "use_discordはfalseがデフォルト" do
      expect(setting.use_discord).to be false
    end

    it "use_slackはfalseがデフォルト" do
      expect(setting.use_slack).to be false
    end

    it "email_modeはdigestがデフォルト" do
      expect(setting.email_mode).to eq("digest")
    end

    it "digest_timeは08:00がデフォルト" do
      expect(setting.digest_time).to eq("08:00")
      expect(setting.digest_hour).to eq(8)
      expect(setting.digest_minute).to eq(0)
    end

    it "email_count_this_monthは0がデフォルト" do
      expect(setting.email_count_this_month).to eq(0)
    end
  end

  describe "メール通知機能" do
    describe "email_mode enum" do
      let(:setting) { create(:notification_setting) }

      it "email_mode_off?が正しく動作する" do
        setting.update(email_mode: :off)
        expect(setting.email_mode_off?).to be true
        expect(setting.email_mode_digest?).to be false
        expect(setting.email_mode_realtime?).to be false
      end

      it "email_mode_digest?が正しく動作する" do
        setting.update(email_mode: :digest)
        expect(setting.email_mode_digest?).to be true
        expect(setting.email_mode_off?).to be false
        expect(setting.email_mode_realtime?).to be false
      end

      it "email_mode_realtime?が正しく動作する" do
        setting.update(email_mode: :realtime)
        expect(setting.email_mode_realtime?).to be true
        expect(setting.email_mode_off?).to be false
        expect(setting.email_mode_digest?).to be false
      end
    end

    describe "#digest_time=" do
      let(:setting) { create(:notification_setting) }

      it "HH:MM:SS形式の文字列をHH:MM形式に正規化する" do
        setting.digest_time = "15:30:00"
        expect(setting.digest_time).to eq("15:30")
        expect(setting.digest_hour).to eq(15)
        expect(setting.digest_minute).to eq(30)
      end

      it "HH:MM形式の文字列をそのまま受け入れる" do
        setting.digest_time = "18:45"
        expect(setting.digest_time).to eq("18:45")
        expect(setting.digest_hour).to eq(18)
        expect(setting.digest_minute).to eq(45)
      end

      it "不正な形式の文字列はそのまま渡す" do
        expect { setting.digest_time = "invalid" }.not_to raise_error
      end
    end

    describe "#can_send_realtime_email?" do
      context "email_modeがrealtimeではない場合" do
        it "offモードではfalseを返す" do
          setting = create(:notification_setting, :email_off)
          expect(setting.can_send_realtime_email?).to be false
        end

        it "digestモードではfalseを返す" do
          setting = create(:notification_setting, :email_digest)
          expect(setting.can_send_realtime_email?).to be false
        end
      end

      context "email_modeがrealtimeの場合" do
        it "カウンターが上限未満ならtrueを返す" do
          setting = create(:notification_setting, :email_realtime)
          setting.update(email_count_this_month: 50, email_count_reset_at: Date.current.beginning_of_month)
          expect(setting.can_send_realtime_email?).to be true
        end

        it "カウンターが99ならtrueを返す" do
          setting = create(:notification_setting, :near_email_limit)
          expect(setting.can_send_realtime_email?).to be true
        end

        it "カウンターが100ならfalseを返す" do
          setting = create(:notification_setting, :at_email_limit)
          expect(setting.can_send_realtime_email?).to be false
        end

        it "カウンターが上限超過ならfalseを返す" do
          setting = create(:notification_setting, :email_realtime)
          setting.update(email_count_this_month: 150, email_count_reset_at: Date.current.beginning_of_month)
          expect(setting.can_send_realtime_email?).to be false
        end

        it "月が変わってリセットが必要な場合は0としてカウントする" do
          setting = create(:notification_setting, :email_realtime)
          setting.update(
            email_count_this_month: 100,
            email_count_reset_at: 1.month.ago.beginning_of_month
          )
          expect(setting.can_send_realtime_email?).to be true
        end

        it "email_count_reset_atがnilの場合は0としてカウントする" do
          setting = create(:notification_setting, :email_realtime)
          setting.update(email_count_this_month: 50, email_count_reset_at: nil)
          expect(setting.can_send_realtime_email?).to be true
        end
      end
    end

    describe "#increment_email_count!" do
      context "email_modeがrealtimeの場合" do
        it "カウンターを1増やす" do
          setting = create(:notification_setting, :email_realtime)
          setting.update(email_count_this_month: 10, email_count_reset_at: Date.current.beginning_of_month)

          expect { setting.increment_email_count! }.to change { setting.reload.email_count_this_month }.from(10).to(11)
        end

        it "上限到達時にダイジェストモードに切り替わる" do
          setting = create(:notification_setting, :near_email_limit)

          setting.increment_email_count!

          expect(setting.reload.email_count_this_month).to eq(100)
          expect(setting.email_mode_digest?).to be true
        end

        it "データベースに正しく保存される" do
          setting = create(:notification_setting, :email_realtime)
          setting.update(email_count_this_month: 50, email_count_reset_at: Date.current.beginning_of_month)

          setting.increment_email_count!
          setting.reload

          expect(setting.email_count_this_month).to eq(51)
        end
      end

      context "email_modeがrealtime以外の場合" do
        it "offモードでは何もしない" do
          setting = create(:notification_setting, :email_off)
          setting.update(email_count_this_month: 10)

          expect { setting.increment_email_count! }.not_to change { setting.reload.email_count_this_month }
        end

        it "digestモードでは何もしない" do
          setting = create(:notification_setting, :email_digest)
          setting.update(email_count_this_month: 10)

          expect { setting.increment_email_count! }.not_to change { setting.reload.email_count_this_month }
        end
      end
    end

    describe "#remaining_emails_this_month" do
      context "email_modeがrealtimeの場合" do
        it "残り配信可能数を正しく返す" do
          setting = create(:notification_setting, :email_realtime)
          setting.update(email_count_this_month: 30, email_count_reset_at: Date.current.beginning_of_month)

          expect(setting.remaining_emails_this_month).to eq(70)
        end

        it "上限到達時は0を返す" do
          setting = create(:notification_setting, :at_email_limit)
          expect(setting.remaining_emails_this_month).to eq(0)
        end

        it "上限超過時は0を返す（マイナスにならない）" do
          setting = create(:notification_setting, :email_realtime)
          setting.update(email_count_this_month: 150, email_count_reset_at: Date.current.beginning_of_month)

          expect(setting.remaining_emails_this_month).to eq(0)
        end

        it "月が変わってリセットが必要な場合は100を返す" do
          setting = create(:notification_setting, :email_realtime)
          setting.update(
            email_count_this_month: 80,
            email_count_reset_at: 1.month.ago.beginning_of_month
          )

          expect(setting.remaining_emails_this_month).to eq(100)
        end

        it "email_count_reset_atがnilの場合は100を返す" do
          setting = create(:notification_setting, :email_realtime)
          setting.update(email_count_this_month: 50, email_count_reset_at: nil)

          expect(setting.remaining_emails_this_month).to eq(100)
        end
      end

      context "email_modeがrealtime以外の場合" do
        it "offモードではnilを返す" do
          setting = create(:notification_setting, :email_off)
          expect(setting.remaining_emails_this_month).to be_nil
        end

        it "digestモードではnilを返す" do
          setting = create(:notification_setting, :email_digest)
          expect(setting.remaining_emails_this_month).to be_nil
        end
      end
    end

    describe "#reset_counter_if_needed!" do
      let(:setting) { create(:notification_setting, :email_realtime) }

      context "リセットが必要な場合" do
        it "email_count_reset_atがnilの時にリセットする" do
          setting.update(email_count_this_month: 50, email_count_reset_at: nil)

          setting.reset_counter_if_needed!
          setting.reload

          expect(setting.email_count_this_month).to eq(0)
          expect(setting.email_count_reset_at).to eq(Date.current.beginning_of_month)
        end

        it "月が変わった時にリセットする" do
          setting.update(
            email_count_this_month: 80,
            email_count_reset_at: 1.month.ago.beginning_of_month
          )

          setting.reset_counter_if_needed!
          setting.reload

          expect(setting.email_count_this_month).to eq(0)
          expect(setting.email_count_reset_at).to eq(Date.current.beginning_of_month)
        end

        it "2ヶ月以上前でもリセットする" do
          setting.update(
            email_count_this_month: 100,
            email_count_reset_at: 3.months.ago.beginning_of_month
          )

          setting.reset_counter_if_needed!
          setting.reload

          expect(setting.email_count_this_month).to eq(0)
          expect(setting.email_count_reset_at).to eq(Date.current.beginning_of_month)
        end
      end

      context "リセットが不要な場合" do
        it "今月のデータはリセットしない" do
          setting.update(
            email_count_this_month: 50,
            email_count_reset_at: Date.current.beginning_of_month
          )

          expect { setting.reset_counter_if_needed! }.not_to change { setting.reload.email_count_this_month }
        end
      end
    end

    describe "月境界での動作" do
      it "月末から月初への移行で正しくリセットされる" do
        travel_to Time.zone.local(2026, 1, 31, 23, 59) do
          setting = create(:notification_setting, :email_realtime)
          setting.update(
            email_count_this_month: 95,
            email_count_reset_at: Date.current.beginning_of_month
          )

          # 1月31日時点ではリセット不要
          expect(setting.can_send_realtime_email?).to be true
          expect(setting.remaining_emails_this_month).to eq(5)
        end

        travel_to Time.zone.local(2026, 2, 1, 0, 1) do
          setting = NotificationSetting.last
          setting.reset_counter_if_needed!

          # 2月1日になったらリセットされる
          expect(setting.reload.email_count_this_month).to eq(0)
          expect(setting.remaining_emails_this_month).to eq(100)
          expect(setting.can_send_realtime_email?).to be true
        end
      end
    end

    describe "上限到達からの月リセット" do
      it "上限到達してダイジェストに切り替わった後、月が変わると再度realtimeモードで配信可能になる" do
        travel_to Time.zone.local(2026, 1, 15, 12, 0) do
          setting = create(:notification_setting, :at_email_limit)
          # 上限到達により自動的にダイジェストに切り替え
          setting.update(email_mode: :digest)

          expect(setting.email_mode_digest?).to be true
          expect(setting.email_count_this_month).to eq(100)
        end

        travel_to Time.zone.local(2026, 2, 1, 8, 0) do
          setting = NotificationSetting.last
          # ユーザーが手動でrealtimeに戻す
          setting.update(email_mode: :realtime)
          setting.reset_counter_if_needed!

          expect(setting.reload.email_count_this_month).to eq(0)
          expect(setting.remaining_emails_this_month).to eq(100)
          expect(setting.can_send_realtime_email?).to be true
        end
      end
    end
  end
end
