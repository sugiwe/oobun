class Subscription < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :thread, class_name: "CorrespondenceThread", foreign_key: :thread_id

  # Validations
  validates :user_id, uniqueness: { scope: :thread_id, message: "はすでにこのスレッドを購読しています" }
end
