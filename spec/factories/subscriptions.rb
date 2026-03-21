FactoryBot.define do
  factory :subscription do
    association :user
    association :thread, factory: :correspondence_thread

    created_at { Time.current }
    updated_at { Time.current }
  end
end
