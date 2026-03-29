FactoryBot.define do
  factory :membership do
    association :user
    association :thread, factory: :correspondence_thread

    # 基本属性
    sequence(:position) { |n| n }
    role { "member" }

    # タイムスタンプ
    created_at { Time.current }
    updated_at { Time.current }

    # Trait: 管理者
    trait :moderator do
      role { "moderator" }
    end

    # Trait: オーナー
    trait :owner do
      role { "owner" }
    end
  end
end
