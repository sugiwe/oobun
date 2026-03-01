class Post < ApplicationRecord
  # Enums
  enum :status, { draft: "draft", published: "published" }, default: :published

  # Associations
  belongs_to :thread, class_name: "CorrespondenceThread", foreign_key: :thread_id
  belongs_to :user
  has_one_attached :thumbnail

  # Validations
  validates :title, presence: true, length: { maximum: 100 }, if: :published?
  validates :title, length: { maximum: 100 }, allow_blank: true, if: :draft?
  validates :body, presence: true, length: { in: 10..10_000 }

  # Scopes
  scope :published_posts, -> { where(status: "published").order(created_at: :asc) }
  scope :draft_posts, -> { where(status: "draft") }

  # Default scope: 公開済み投稿のみ表示
  default_scope -> { published_posts }

  # 前後のナビゲーション（公開済み投稿のみ）
  def prev
    thread.posts.unscope(where: :status)
          .where(status: "published")
          .where("created_at < ?", created_at)
          .order(created_at: :desc)
          .first
  end

  def next
    thread.posts.unscope(where: :status)
          .where(status: "published")
          .where("created_at > ?", created_at)
          .order(created_at: :asc)
          .first
  end

  # 編集可能かどうか（作成者のみ）
  def editable_by?(user)
    return false unless user
    self.user_id == user.id
  end

  # 下書きを公開する
  def publish!
    update!(status: "published")
  end

  # 公開可能かどうか（自分のターンかつ下書き）
  def can_publish?(user)
    return false unless draft?
    return false unless editable_by?(user)
    thread.my_turn?(user)
  end
end
