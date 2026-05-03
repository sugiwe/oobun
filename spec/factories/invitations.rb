FactoryBot.define do
  factory :invitation do
    # 関連
    association :thread, factory: :correspondence_thread
    association :invited_by, factory: :user

    # 基本属性
    invitation_type { "single_use" }
    expiry_type { "seven_days" }
    use_count { 0 }

    # タイムスタンプ（コールバックで自動設定されるがテスト用に明示）
    created_at { Time.current }
    updated_at { Time.current }
    accepted_at { nil }
    last_used_at { nil }

    # token と expires_at は before_validation コールバックで自動生成

    # Trait: 無制限招待
    trait :unlimited do
      invitation_type { "unlimited" }
      expiry_type { "unlimited" }
    end

    # Trait: 期限なし
    trait :no_expiry do
      expiry_type { "unlimited" }
    end

    # Trait: 使用済み
    trait :used do
      use_count { 1 }
      accepted_at { 1.hour.ago }
      last_used_at { 1.hour.ago }
    end

    # Trait: 期限切れ
    trait :expired do
      expiry_type { "seven_days" }
      after(:create) do |invitation|
        invitation.update_column(:expires_at, 1.day.ago)
      end
    end
  end
end
