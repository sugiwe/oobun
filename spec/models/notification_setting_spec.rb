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
  end
end
