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

    # Trait: 下書き
    trait :draft do
      status { :draft }
      title { nil }
      body { Faker::Lorem.paragraph }
    end

    # Trait: 匿名化済み
    trait :anonymized do
      status { :anonymized }
      title { Post::ANONYMIZED_TITLE }
    end
  end
end
