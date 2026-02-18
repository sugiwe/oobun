class CorrespondenceThread < ApplicationRecord
  self.table_name = "threads"

  # ルーティングヘルパーを :thread ベースで生成（thread_path, new_thread_path など）
  def self.model_name
    ActiveModel::Name.new(self, nil, "Thread")
  end

  # Associations
  has_many :memberships, foreign_key: :thread_id, dependent: :destroy
  has_many :users, through: :memberships
  has_many :posts, foreign_key: :thread_id, dependent: :destroy
  has_many :subscriptions, foreign_key: :thread_id, dependent: :destroy
  has_many :subscribers, through: :subscriptions, source: :user
  has_many :skips, foreign_key: :thread_id, dependent: :destroy

  # Validations
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true,
    format: { with: /\A[a-z0-9-]+\z/, message: "英数字とハイフンのみ使用できます" },
    length: { in: 3..50 }
  validates :visibility, presence: true, inclusion: { in: %w[public url_only followers_only paid] }
  validates :turn_based, inclusion: { in: [true, false] }
  validate :slug_not_reserved

  # Reserved slugs
  RESERVED_SLUGS = %w[
    admin api about help settings terms privacy posts users new edit
    login logout auth oauth callback feeds rss assets rails
  ].freeze

  private

  def slug_not_reserved
    errors.add(:slug, "は予約語のため使用できません") if RESERVED_SLUGS.include?(slug)
  end
end
