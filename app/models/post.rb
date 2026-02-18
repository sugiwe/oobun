class Post < ApplicationRecord
  # Associations
  belongs_to :thread, class_name: "CorrespondenceThread", foreign_key: :thread_id
  belongs_to :user

  # Validations
  validates :body, presence: true, length: { in: 10..10_000 }

  # Scopes
  default_scope -> { order(created_at: :asc) }
end
