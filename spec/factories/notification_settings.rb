FactoryBot.define do
  factory :notification_setting do
    association :user

    # デフォルト値（マイグレーションと同じ）
    notify_member_posts { true }
    notify_subscription_posts { true }
    use_discord { false }
    use_slack { false }
    discord_webhook_url { nil }
    slack_webhook_url { nil }

    # メール通知のデフォルト値
    email_mode { "digest" }
    digest_time { "08:00" }
    email_count_this_month { 0 }
    email_count_reset_at { nil }

    trait :with_discord do
      use_discord { true }
      discord_webhook_url { "https://discord.com/api/webhooks/123456789/abcdefg" }
    end

    trait :with_slack do
      use_slack { true }
      slack_webhook_url { "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXX" }
    end

    trait :email_off do
      email_mode { "off" }
    end

    trait :email_digest do
      email_mode { "digest" }
      digest_time { "08:00" }
    end

    trait :email_realtime do
      email_mode { "realtime" }
      email_count_this_month { 0 }
      email_count_reset_at { Date.current.beginning_of_month }
    end

    trait :near_email_limit do
      email_mode { "realtime" }
      email_count_this_month { 99 }
      email_count_reset_at { Date.current.beginning_of_month }
    end

    trait :at_email_limit do
      email_mode { "realtime" }
      email_count_this_month { 100 }
      email_count_reset_at { Date.current.beginning_of_month }
    end
  end
end
