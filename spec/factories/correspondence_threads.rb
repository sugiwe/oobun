FactoryBot.define do
  factory :correspondence_thread, class: "CorrespondenceThread" do
    # 基本属性
    sequence(:slug) { |n| "thread-#{n}" }
    title { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    status { :draft }
    turn_based { false }
    show_in_list { true }
    is_sample { false }

    # タイムスタンプ
    created_at { Time.current }
    updated_at { Time.current }
    last_posted_at { nil }

    # Trait: 公開スレッド
    trait :free do
      status { :free }
    end

    # Trait: 交代制
    trait :turn_based do
      turn_based { true }
    end

    # Trait: サンプルスレッド
    trait :sample do
      is_sample { true }
    end
  end
end
