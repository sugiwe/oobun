FactoryBot.define do
  factory :notification_setting do
    association :user

    # デフォルト値（マイグレーションと同じ）
    notify_member_posts { true }
    notify_subscription_posts { true }
    notify_invitations { true }
    use_discord { false }
    use_slack { false }
    discord_webhook_url { nil }
    slack_webhook_url { nil }

    trait :with_discord do
      use_discord { true }
      discord_webhook_url { "https://discord.com/api/webhooks/123456789/abcdefg" }
    end

    trait :with_slack do
      use_slack { true }
      slack_webhook_url { "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXX" }
    end
  end
end
