FactoryBot.define do
  factory :monthly_signup_quota do
    year_month { "MyString" }
    quota_limit { 1 }
    signups_count { 1 }
  end
end
