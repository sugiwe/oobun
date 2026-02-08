class Skip < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :thread

  # Scopes
  default_scope -> { order(created_at: :desc) }
end
