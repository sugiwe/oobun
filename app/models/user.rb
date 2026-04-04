class User < ApplicationRecord
  # Admin email addresses cached at boot time
  ADMIN_EMAIL_SET = ENV.fetch("ADMIN_EMAILS", "").split(",").map(&:strip).to_set.freeze

  # 匿名化された退会ユーザーの表示名
  ANONYMIZED_DISPLAY_NAME = "退会済みユーザー"

  # Associations
  has_many :memberships, dependent: :destroy
  has_many :correspondence_threads, through: :memberships, source: :thread
  has_many :posts, -> { unscope(where: :status) }, dependent: :destroy
  has_many :published_posts, -> { published_posts }, class_name: "Post"
  has_many :draft_posts, -> { draft_posts }, class_name: "Post"
  has_many :subscriptions, dependent: :destroy
  has_many :subscribed_threads, through: :subscriptions, source: :thread
  has_many :skips, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_one :notification_setting, dependent: :destroy
  has_one_attached :avatar

  # Callbacks
  after_create :create_default_notification_setting
  after_create :send_welcome_notification

  # Validations
  validates :username, presence: true, uniqueness: true,
    format: { with: /\A[a-zA-Z0-9_-]+\z/, message: "英数字、ハイフン、アンダースコアのみ使用できます" },
    length: { in: 3..20 }
  validates :display_name, presence: true, length: { maximum: 50 }
  validates :email, presence: true, uniqueness: true
  validates :google_uid, uniqueness: true, allow_nil: true
  validates :bio, length: { maximum: 5000 }, allow_blank: true
  validates :avatar, content_type: [ "image/png", "image/jpeg", "image/gif", "image/webp" ],
                     size: { less_than: 5.megabytes }
  validate :check_storage_limit_for_avatar, if: -> { avatar.attached? && avatar.changed? }

  # アバターストレージ容量チェック
  # NOTE: 複数同時アップロードによる競合状態で100MBを若干超過する可能性があるが、
  # 1画像5MB制限により最大でも105MB程度に抑えられるため許容範囲とする
  def check_storage_limit_for_avatar
    return unless avatar.attached?

    new_file_size = avatar.blob.byte_size
    unless can_upload?(new_file_size)
      errors.add(:avatar, "ストレージ容量の上限（#{MAX_STORAGE_PER_USER / 1.megabyte}MB）を超えています")
    end
  end

  # Google OAuth ログイン用クラスメソッド
  def self.find_or_initialize_from_google(payload)
    find_or_initialize_by(google_uid: payload["sub"]).tap do |user|
      # email は常に最新の情報に更新
      user.email = payload["email"]

      # 新規ユーザーの場合のみ Google の情報を設定
      if user.new_record?
        user.display_name = payload["name"]
        user.avatar_url   = payload["picture"]
        # username は別画面で設定
      end
    end
  end

  # パーソナライズドフィード用データ取得
  def personalized_feed_data
    {
      my_turn_posts: fetch_my_turn_posts,
      participated_threads: fetch_participated_threads,
      followed_threads: fetch_followed_threads,
      recent_posts: fetch_recent_posts
    }
  end

  # 使用制限チェック
  MAX_THREADS_PER_USER = 10
  MAX_STORAGE_PER_USER = 100.megabytes
  MAX_POSTS_PER_HOUR = 10  # 下書き・公開含む（新規作成のみカウント、更新は除外）
  MAX_POSTS_PER_DAY = 50   # 下書き・公開含む（新規作成のみカウント、更新は除外）

  def can_join_thread?
    correspondence_threads.count < MAX_THREADS_PER_USER
  end

  def threads_remaining
    MAX_THREADS_PER_USER - correspondence_threads.count
  end

  def storage_used
    # ユーザーのアバター + 投稿のサムネイル画像の合計サイズ
    total = 0
    total += avatar.blob.byte_size if avatar.attached?
    # データベースレベルでSUMを計算してN+1問題を回避
    total += posts.unscope(where: :status)
                  .joins(thumbnail_attachment: :blob)
                  .sum("active_storage_blobs.byte_size")
    total
  end

  def storage_remaining
    MAX_STORAGE_PER_USER - storage_used
  end

  def can_upload?(file_size)
    storage_used + file_size <= MAX_STORAGE_PER_USER
  end

  def post_rate_limit_exceeded?
    posts_in_last_hour >= MAX_POSTS_PER_HOUR || posts_today >= MAX_POSTS_PER_DAY
  end

  def posts_in_last_hour
    # 下書き・公開問わず、すべての投稿をカウント
    posts.unscope(where: :status)
         .where("created_at > ?", 1.hour.ago)
         .count
  end

  def posts_today
    # 日本時間の0時から現在まで、下書き・公開問わずカウント
    today_start = Time.current.in_time_zone("Tokyo").beginning_of_day
    posts.unscope(where: :status)
         .where("created_at >= ?", today_start)
         .count
  end

  def admin?
    ADMIN_EMAIL_SET.include?(email)
  end

  # 退会済みかどうか
  def deleted?
    deleted_at.present?
  end

  # 正規化されたメールアドレスを返す（DRY原則）
  def normalized_email
    email.downcase.strip
  end

  private

  # 通知設定のデフォルト値を作成
  def create_default_notification_setting
    build_notification_setting(
      notify_member_posts: true,
      notify_subscription_posts: true,
      email_mode: :digest,
      digest_time: "08:00"
    ).tap(&:save!)
  end

  # ウェルカム通知を送信
  def send_welcome_notification
    notifications.create!(
      actor: nil,
      notifiable: self,
      action: :welcome
    )
  end

  # 1. 自分のターンの交換日記の最新投稿を取得（N+1問題を解決）
  def fetch_my_turn_posts
    # 自分のターンの交換日記IDを取得（membershipsを事前ロード）
    # 参加中のスレッドは非公開でも表示
    my_turn_thread_ids = correspondence_threads
                          .includes(:memberships)
                          .where(turn_based: true)
                          .select { |t| t.my_turn?(self) }
                          .map(&:id)

    return Post.none if my_turn_thread_ids.empty?

    # 各交換日記の公開済み投稿を取得してRuby側で最新を抽出
    # （N+1は解決済み：includes で関連データを一括ロード）
    # default_scope を上書きするため reorder を使用
    posts = Post.unscope(where: :status)
                .where(status: "published")
                .includes(:user, :thread)
                .where(thread_id: my_turn_thread_ids)
                .reorder(created_at: :desc)

    # 交換日記ごとにグループ化して最新の投稿のみ取得
    posts.group_by(&:thread_id)
         .map { |_, thread_posts| thread_posts.first }
         .sort_by(&:created_at)
         .reverse
  end

  # 2. 参加中の交換日記を取得（非公開も含む）
  def fetch_participated_threads
    correspondence_threads
      .includes(:users, :memberships)
      .recent_order
  end

  # 3. フォロー中の交換日記（参加中を除く）を取得
  def fetch_followed_threads
    participated_ids = correspondence_threads.pluck(:id)

    subscribed_threads
      .public_threads
      .includes(:users, :memberships)
      .where.not(id: participated_ids)
      .recent_order
  end

  # 4. フォロー中交換日記の新着投稿を取得（冗長なクエリを削減）
  def fetch_recent_posts(limit: 5)
    Post.unscope(where: :status)
        .where(status: "published")
        .includes(:user, :thread)
        .where(thread_id: subscribed_threads.public_threads.select(:id))
        .reorder(created_at: :desc)
        .limit(limit)
  end
end
