class CreateMonthlySignupQuota < ActiveRecord::Migration[8.1]
  def change
    create_table :monthly_signup_quota do |t|
      t.string :year_month, null: false
      t.integer :quota_limit, null: false, default: 100  # MonthlySignupQuota::DEFAULT_QUOTA_LIMIT
      t.integer :signups_count, null: false, default: 0

      t.timestamps
    end

    add_index :monthly_signup_quota, :year_month, unique: true
  end
end
