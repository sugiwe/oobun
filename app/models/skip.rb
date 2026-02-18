class Skip < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :thread, class_name: "CorrespondenceThread", foreign_key: :thread_id

  # Scopes
  default_scope -> { order(created_at: :desc) }
end
