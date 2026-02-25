class Post < ApplicationRecord
  # Associations
  belongs_to :thread, class_name: "CorrespondenceThread", foreign_key: :thread_id
  belongs_to :user
  has_one_attached :thumbnail

  # Validations
  validates :title, presence: true, length: { maximum: 100 }
  validates :body, presence: true, length: { in: 10..10_000 }

  # Scopes
  default_scope -> { order(created_at: :asc) }

  # 前後のナビゲーション
  def prev
    thread.posts.where("created_at < ?", created_at).reorder(created_at: :desc).first
  end

  def next
    thread.posts.where("created_at > ?", created_at).reorder(created_at: :asc).first
  end

  # 編集可能かどうか（作成者のみ）
  def editable_by?(user)
    return false unless user
    self.user_id == user.id
  end
end
