class Membership < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :thread, class_name: "CorrespondenceThread", foreign_key: :thread_id

  # Validations
  validates :position, presence: true, uniqueness: { scope: :thread_id }
  validates :role, presence: true, inclusion: { in: %w[writer] }
  validates :user_id, uniqueness: { scope: :thread_id, message: "はすでにこのスレッドのメンバーです" }
end
