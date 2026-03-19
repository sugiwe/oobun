FactoryBot.define do
  factory :membership do
    association :user
    association :thread, factory: :correspondence_thread

    # 基本属性
    sequence(:position) { |n| n }
    role { "writer" }

    # タイムスタンプ
    created_at { Time.current }
    updated_at { Time.current }
  end
end
