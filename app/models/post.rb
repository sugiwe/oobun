class Post < ApplicationRecord
  # 匿名化された投稿のタイトル
  ANONYMIZED_TITLE = "[削除済み]"

  # Enums
  enum :status, { draft: "draft", published: "published", anonymized: "anonymized" }, default: :published

  # Associations
  belongs_to :thread, class_name: "CorrespondenceThread", foreign_key: :thread_id
  belongs_to :user
  has_one_attached :thumbnail
  has_many :notifications, as: :notifiable, dependent: :destroy

  # Validations
  validates :title, length: { maximum: 100 }, allow_blank: true
  validates :body, presence: true, length: { in: 10..10_000 }, if: :published?
  validates :body, length: { maximum: 10_000 }, allow_blank: true, if: :draft?
  validates :thumbnail, content_type: [ "image/png", "image/jpeg", "image/gif", "image/webp" ],
                        size: { less_than: 5.megabytes }
  validates :slug, uniqueness: { scope: :thread_id }, allow_nil: true
  validates :slug, format: { with: /\A(?!\d+\z)[a-z0-9\-]+\z/, message: "は英小文字、数字、ハイフンのみ使用でき、数字のみにすることはできません" }, allow_blank: true
  validate :check_user_storage_limit, if: -> { thumbnail.attached? && thumbnail.changed? }
  validate :check_posting_rules, on: :create, if: :published?

  # ストレージ容量チェック
  # NOTE: 複数同時アップロードによる競合状態で100MBを若干超過する可能性があるが、
  # 1画像5MB制限により最大でも105MB程度に抑えられるため許容範囲とする
  def check_user_storage_limit
    return unless thumbnail.attached?
    return unless user

    new_file_size = thumbnail.blob.byte_size
    unless user.can_upload?(new_file_size)
      errors.add(:thumbnail, "ストレージ容量の上限（#{user.max_storage_per_user / 1.megabyte}MB）を超えています")
    end
  end

  # 投稿ルールチェック
  def check_posting_rules
    return unless thread && user
    return if thread.my_turn?(user)

    message = if thread.posting_mode_relay?
      "今はあなたのターンではありません"
    elsif thread.posting_mode_rotation?
      "連続投稿はできません。他のメンバーが投稿するまでお待ちください"
    end

    errors.add(:base, message) if message
  end

  # Scopes
  # published_at 順（バックフィル済みのため published_at を直接使用）
  scope :published_posts, -> { where(status: [ "published", "anonymized" ]).order(published_at: :asc) }
  scope :draft_posts, -> { where(status: "draft") }

  # Default scope: 公開済み投稿と匿名化済み投稿を表示（下書きは除外）
  default_scope -> { published_posts }

  # 前後のナビゲーション（公開済み投稿のみ）
  def prev
    thread.posts.unscope(where: :status)
          .where(status: "published")
          .where("published_at < ?", published_at)
          .reorder(published_at: :desc)
          .first
  end

  def next
    thread.posts.unscope(where: :status)
          .where(status: "published")
          .where("published_at > ?", published_at)
          .reorder(published_at: :asc)
          .first
  end

  # 編集可能かどうか（作成者のみ）
  def editable_by?(user)
    return false unless user
    self.user_id == user.id
  end

  # 表示用の公開日時（published_at があればそれを、なければ created_at をフォールバック）
  def display_published_at
    published_at || created_at
  end

  # 表示用のタイトル（空欄の場合は公開日時から生成）
  def display_title
    return title if title.present?
    return ANONYMIZED_TITLE if anonymized?
    display_published_at.in_time_zone("Tokyo").strftime("%Y年%-m月%-d日")
  end

  # 下書きを公開する
  def publish!
    # カスタムslugが設定されていない場合、または日付のみの場合は公開時に連番を付与
    if slug.blank? || slug.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      # トランザクション内でスレッドをロックして、同時公開による競合を防ぐ
      Post.transaction do
        # スレッドをロックして、同じスレッド内の同時公開をブロック
        thread.lock!

        # published_atを設定してから保存（コールバックで再度slug生成されないようにslugを先に設定）
        self.published_at = Time.current
        self.slug = generate_sequential_slug(self.published_at)
        # タイトルが空の場合は日付を自動設定（RSS対応）
        if title.blank?
          self.title = published_at.in_time_zone("Tokyo").strftime("%Y年%-m月%-d日")
        end
        self.status = "published"
        save!
      end
    else
      # カスタムslugの場合は通常通り更新
      self.published_at = Time.current
      # タイトルが空の場合は日付を自動設定（RSS対応）
      if title.blank?
        self.title = published_at.in_time_zone("Tokyo").strftime("%Y年%-m月%-d日")
      end
      update!(status: "published")
    end
  end

  # 公開可能かどうか（自分のターンかつ下書き）
  def can_publish?(user)
    return false unless draft?
    return false unless editable_by?(user)
    thread.my_turn?(user)
  end

  # URLパラメータ用（公開済みでslugがあればslug、それ以外はID）
  def to_param
    # 下書きは常にID、公開済みはslugがあればslug、なければID
    if draft?
      id.to_s
    else
      slug.presence || id.to_s
    end
  end

  # Callbacks
  # 投稿作成・更新前にslugを自動生成（slug未指定 かつ published_atが設定されている場合）
  before_validation :generate_slug, if: -> { slug.blank? && published_at.present? }

  # 投稿が公開状態になった時、スレッドの自動公開をチェック
  # (create時だけでなく、draft→publishedへの更新時にも対応)
  after_commit :check_auto_publish_thread, if: -> { saved_change_to_status?(to: "published") }

  # 投稿が公開状態になった時に通知を送信
  # (create時だけでなく、draft→publishedへの更新時にも対応)
  after_commit :notify_subscribers, if: -> { saved_change_to_status?(to: "published") }

  private

  # slug自動生成（公開日時ベース: 2026-04-11-1 形式）
  def generate_slug
    return if slug.present?
    return unless published_at.present?

    self.slug = generate_sequential_slug(published_at)
  end

  # 連番付きslugを生成（YYYY-MM-DD-N 形式）
  def generate_sequential_slug(timestamp)
    tokyo_time = timestamp.in_time_zone("Tokyo")
    date = tokyo_time.strftime("%Y-%m-%d")

    # その日のスレッド内の既存slugから最大値を取得してインクリメント
    # 削除された投稿があっても連番が重複しない
    slugs = thread.posts
                  .where(published_at: tokyo_time.all_day)
                  .where("slug LIKE ?", "#{date}-%")
                  .pluck(:slug)
    max_num = slugs.map { |s| s.split("-").last.to_i }.max || 0
    count = max_num + 1

    "#{date}-#{count}"
  end

  def check_auto_publish_thread
    return unless thread.draft?
    return unless thread.published_posts.count >= CorrespondenceThread::AUTO_PUBLISH_POSTS_THRESHOLD

    thread.auto_publish!
  end

  def notify_subscribers
    NotificationService.notify_new_post(self)
  end
end
