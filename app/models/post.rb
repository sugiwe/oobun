class Post < ApplicationRecord
  # Enums
  enum :status, { draft: "draft", published: "published", anonymized: "anonymized" }, default: :published

  # Associations
  belongs_to :thread, class_name: "CorrespondenceThread", foreign_key: :thread_id
  belongs_to :user
  has_one_attached :thumbnail

  # Validations
  validates :title, presence: true, length: { maximum: 100 }, if: :published?
  validates :title, length: { maximum: 100 }, allow_blank: true, if: :draft?
  validates :body, presence: true, length: { in: 10..10_000 }, if: :published?
  validates :body, length: { maximum: 10_000 }, allow_blank: true, if: :draft?
  validates :thumbnail, content_type: [ "image/png", "image/jpeg", "image/gif", "image/webp" ],
                        size: { less_than: 5.megabytes }
  validate :check_user_storage_limit, if: -> { thumbnail.attached? && thumbnail.changed? }

  # ストレージ容量チェック
  # NOTE: 複数同時アップロードによる競合状態で100MBを若干超過する可能性があるが、
  # 1画像5MB制限により最大でも105MB程度に抑えられるため許容範囲とする
  def check_user_storage_limit
    return unless thumbnail.attached?
    return unless user

    new_file_size = thumbnail.blob.byte_size
    unless user.can_upload?(new_file_size)
      errors.add(:thumbnail, "ストレージ容量の上限（#{User::MAX_STORAGE_PER_USER / 1.megabyte}MB）を超えています")
    end
  end

  # Scopes
  scope :published_posts, -> { where(status: [ "published", "anonymized" ]).order(created_at: :asc) }
  scope :draft_posts, -> { where(status: "draft") }

  # Default scope: 公開済み投稿と匿名化済み投稿を表示（下書きは除外）
  default_scope -> { published_posts }

  # 前後のナビゲーション（公開済み投稿のみ）
  def prev
    thread.posts.unscope(where: :status)
          .where(status: "published")
          .where("created_at < ?", created_at)
          .reorder(created_at: :desc)
          .first
  end

  def next
    thread.posts.unscope(where: :status)
          .where(status: "published")
          .where("created_at > ?", created_at)
          .reorder(created_at: :asc)
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

  # Callbacks
  # 投稿が公開状態になった時、スレッドの自動公開をチェック
  # (create時だけでなく、draft→publishedへの更新時にも対応)
  after_commit :check_auto_publish_thread, if: -> { saved_change_to_status?(to: "published") }

  private

  def check_auto_publish_thread
    return unless thread.draft?
    return unless thread.published_posts.count >= CorrespondenceThread::AUTO_PUBLISH_POSTS_THRESHOLD

    thread.auto_publish!
  end
end
