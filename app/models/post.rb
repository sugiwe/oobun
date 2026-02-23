class Post < ApplicationRecord
  # Associations
  belongs_to :thread, class_name: "CorrespondenceThread", foreign_key: :thread_id
  belongs_to :user

  # タイトル未入力時は投稿日時で自動補完
  before_validation :set_default_title, on: :create

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

  private

  def set_default_title
    if title.blank?
      self.title = (created_at || Time.current).strftime("%Y年%m月%d日")
    end
  end
end
