class User < ApplicationRecord
  # Associations
  has_many :memberships, dependent: :destroy
  has_many :correspondence_threads, through: :memberships, source: :thread
  has_many :posts, -> { unscope(where: :status) }, dependent: :destroy
  has_many :published_posts, -> { published_posts }, class_name: "Post"
  has_many :draft_posts, -> { draft_posts }, class_name: "Post"
  has_many :subscriptions, dependent: :destroy
  has_many :subscribed_threads, through: :subscriptions, source: :thread
  has_many :skips, dependent: :destroy
  has_one_attached :avatar

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

  private

  # 1. 自分のターンの交換日記の最新投稿を取得（N+1問題を解決）
  def fetch_my_turn_posts
    # 自分のターンの交換日記IDを取得（membershipsを事前ロード）
    my_turn_thread_ids = correspondence_threads
                          .includes(:memberships)
                          .where(turn_based: true, visibility: "public")
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

  # 2. 参加中の交換日記を取得
  def fetch_participated_threads
    correspondence_threads
      .includes(:users, :memberships)
      .where(visibility: "public")
      .recent_order
  end

  # 3. フォロー中の交換日記（参加中を除く）を取得
  def fetch_followed_threads
    participated_ids = correspondence_threads.pluck(:id)

    subscribed_threads
      .includes(:users, :memberships)
      .where(visibility: "public")
      .where.not(id: participated_ids)
      .recent_order
  end

  # 4. フォロー中交換日記の新着投稿を取得（冗長なクエリを削減）
  def fetch_recent_posts
    Post.unscope(where: :status)
        .where(status: "published")
        .includes(:user, :thread)
        .where(thread_id: subscribed_threads.select(:id))
        .reorder(created_at: :desc)
        .limit(10)
  end
end
