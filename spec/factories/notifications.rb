FactoryBot.define do
  factory :notification do
    association :user
    association :actor, factory: :user
    association :notifiable, factory: :post
    action { "new_post" }
    params do
      {
        thread_title: "テストスレッド",
        thread_slug: "test-thread",
        post_preview: "テスト投稿のプレビュー"
      }
    end
    read_at { nil }

    trait :read do
      read_at { Time.current }
    end

    trait :invitation do
      action { "invitation" }
    end
  end
end
