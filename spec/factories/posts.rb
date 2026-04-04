FactoryBot.define do
  factory :post do
    association :user
    association :thread, factory: :correspondence_thread

    # 基本属性
    title { Faker::Lorem.sentence(word_count: 3) }
    body { Faker::Lorem.paragraph(sentence_count: 5) }
    status { :published }

    # タイムスタンプ
    created_at { Time.current }
    updated_at { Time.current }
    published_at { Time.current }

    # ユーザーをスレッドのメンバーにする
    after(:build) do |post|
      unless post.thread.memberships.exists?(user: post.user)
        create(:membership, user: post.user, thread: post.thread)
      end
    end

    # Trait: 下書き
    trait :draft do
      status { :draft }
      title { nil }
      body { Faker::Lorem.paragraph }
      published_at { nil }
    end

    # Trait: 匿名化済み
    trait :anonymized do
      status { :anonymized }
      title { Post::ANONYMIZED_TITLE }
    end
  end
end
