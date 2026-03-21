class NotificationSetting < ApplicationRecord
  belongs_to :user

  # バリデーション
  validates :discord_webhook_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[https]), allow_blank: true }
  validates :slack_webhook_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[https]), allow_blank: true }

  # webhook URLが設定されていない場合は、use_discord/use_slackをfalseにする
  before_save :disable_webhooks_if_urls_blank

  private

  def disable_webhooks_if_urls_blank
    self.use_discord = false if discord_webhook_url.blank?
    self.use_slack = false if slack_webhook_url.blank?
  end
end
