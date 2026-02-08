class User < ApplicationRecord
  # Associations
  has_many :memberships, dependent: :destroy
  has_many :threads, through: :memberships
  has_many :posts, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :subscribed_threads, through: :subscriptions, source: :thread
  has_many :skips, dependent: :destroy

  # Validations
  validates :username, presence: true, uniqueness: true,
    format: { with: /\A[a-zA-Z0-9_-]+\z/, message: "英数字、ハイフン、アンダースコアのみ使用できます" },
    length: { in: 3..20 }
  validates :display_name, presence: true
  validates :email, presence: true, uniqueness: true
end
