class Subscription < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :thread

  # Validations
  validates :user_id, uniqueness: { scope: :thread_id, message: "はすでにこのスレッドを購読しています" }
end
