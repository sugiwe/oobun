FactoryBot.define do
  factory :user do
    # 基本属性
    sequence(:username) { |n| "user#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    display_name { Faker::Internet.username(specifier: 3..20) }
    bio { Faker::Lorem.paragraph(sentence_count: 2) }

    # Google OAuth
    sequence(:google_uid) { |n| "google_uid_#{n}" }
    avatar_url { Faker::Avatar.image }

    # タイムスタンプ
    created_at { Time.current }
    updated_at { Time.current }
    deleted_at { nil }

    # Trait: 管理者ユーザー
    trait :admin do
      email { "admin@example.com" }
    end

    # Trait: Google UIDなし（手動登録想定）
    trait :without_google_uid do
      google_uid { nil }
      avatar_url { nil }
    end

    # Trait: 退会済みユーザー
    trait :deleted do
      deleted_at { 1.day.ago }
    end

    # Trait: bioなし
    trait :without_bio do
      bio { nil }
    end

    # Trait: アバター画像添付済み
    trait :with_avatar do
      after(:create) do |user|
        user.avatar.attach(
          io: File.open(Rails.root.join("spec", "fixtures", "files", "test_avatar.png")),
          filename: "test_avatar.png",
          content_type: "image/png"
        )
      end
    end

    # Trait: スレッド参加上限に達している
    trait :at_thread_limit do
      after(:create) do |user|
        create_list(:membership, User::MAX_THREADS_PER_USER, user: user)
      end
    end

    # Trait: 投稿レート制限に達している（時間制限）
    trait :at_hourly_post_limit do
      after(:create) do |user|
        create_list(:post, User::MAX_POSTS_PER_HOUR, user: user, created_at: 30.minutes.ago)
      end
    end

    # Trait: 投稿レート制限に達している（日次制限）
    trait :at_daily_post_limit do
      after(:create) do |user|
        create_list(:post, User::MAX_POSTS_PER_DAY, user: user, created_at: 12.hours.ago)
      end
    end
  end
end
