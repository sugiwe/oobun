FactoryBot.define do
  factory :annotation do
    association :user
    association :post

    # 基本属性
    paragraph_index { 0 }
    start_offset { 0 }
    end_offset { 10 }
    selected_text { "テスト段落" }
    body { "付箋のテスト内容です" }
    visibility { :self_only }

    # タイムスタンプ
    created_at { Time.current }
    updated_at { Time.current }
    invalidated_at { nil }

    # Trait: 公開付箋
    trait :public_visible do
      visibility { :public_visible }
    end

    # Trait: 無効化済み
    trait :invalidated do
      invalidated_at { 1.hour.ago }
    end
  end
end
