require "zip"

class CorrespondenceThread < ApplicationRecord
  self.table_name = "threads"

  # 自動公開・自動削除の閾値
  AUTO_PUBLISH_POSTS_THRESHOLD = 5    # 5投稿で自動公開
  AUTO_PUBLISH_DAYS_THRESHOLD = 30    # 30日で自動公開
  AUTO_DELETE_DAYS_THRESHOLD = 30     # 30日間投稿なしで自動削除

  # ルーティングヘルパーを :thread ベースで生成（thread_path, new_thread_path など）
  def self.model_name
    ActiveModel::Name.new(self, nil, "Thread")
  end

  # 交代制ロジック: 現在のターンのユーザーを返す
  def current_turn_user
    return nil unless turn_based?

    ordered_memberships = memberships.order(:position)
    return ordered_memberships.first&.user if last_post_user_id.nil?

    last_membership = ordered_memberships.find { |m| m.user_id == last_post_user_id }
    return ordered_memberships.first&.user unless last_membership

    next_position = last_membership.position % ordered_memberships.size + 1
    ordered_memberships.find { |m| m.position == next_position }&.user
  end

  def my_turn?(user)
    return true unless turn_based?
    current_turn_user == user
  end

  # メンバーかどうか
  def member?(user)
    return false unless user
    memberships.exists?(user: user)
  end

  # メンバーによって編集可能
  def editable_by?(user)
    member?(user)
  end

  # 特定ユーザーの下書きを取得
  def draft_for(user)
    posts.unscope(where: :status).draft_posts.find_by(user: user)
  end

  # 特定ユーザーの下書きが存在するか
  def has_draft_for?(user)
    draft_for(user).present?
  end

  # 公開済み投稿＋特定ユーザーの下書きを取得（表示用）
  def visible_posts_for(user = nil)
    if user
      posts.unscope(where: :status)
           .where("status = 'published' OR (status = 'draft' AND user_id = ?)", user.id)
    else
      published_posts
    end
  end

  # 最終投稿メタデータを更新（公開済み投稿のみ）
  def update_last_post_metadata!(excluded_post_id: nil)
    scope = posts.unscope(where: :status).where(status: "published")
    scope = scope.where.not(id: excluded_post_id) if excluded_post_id
    last_post = scope.reorder(created_at: :desc).first

    update!(
      last_post_user_id: last_post&.user_id,
      last_posted_at: last_post&.created_at
    )
  end

  # status の enum 定義
  enum :status, {
    draft: "draft",  # 下書き（メンバーのみ）
    free: "free",    # 無料公開
    paid: "paid"     # 有料公開（Phase 3で実装予定）
  }

  # 公開/非公開を切り替え（draft ⇄ free）
  def toggle_published!
    if free? || paid?
      draft!
    else
      free!
    end
  end

  # 閲覧可能かどうか
  def viewable_by?(user)
    return true if member?(user)
    free? || paid?
    # Phase 3: paid の場合は user&.subscribed_to?(self) をチェック
  end

  # 自動公開（電気通信事業法対応）
  def auto_publish!
    return unless draft?

    transaction do
      free!
      Rails.logger.info "Thread #{slug} auto-published: #{published_posts.count} posts, #{days_since_creation} days old"
    end
  end

  # 作成からの経過日数
  def days_since_creation
    (Date.today - created_at.to_date).to_i
  end

  # 非公開に戻せるかどうか（強制公開条件を満たしていない場合のみ可能）
  def can_be_privatized?
    return false if draft? # 既に非公開

    # 5投稿未満 かつ 30日未満であれば非公開に戻せる
    published_posts.count < AUTO_PUBLISH_POSTS_THRESHOLD &&
      days_since_creation < AUTO_PUBLISH_DAYS_THRESHOLD
  end

  # エクスポート用JSON生成（メンバーのみ実行可能）
  def to_export_json(posts_with_includes: nil)
    # postsが渡されていない場合は取得（重複クエリ対策）
    posts_data = posts_with_includes || published_posts.includes(:user).with_attached_thumbnail.order(created_at: :asc)

    {
      thread: {
        title: title,
        slug: slug,
        description: description,
        status: status,
        turn_based: turn_based,
        created_at: created_at,
        thumbnail_filename: thumbnail.attached? ? thumbnail.filename.sanitized : nil
      },
      members: users.map { |user|
        {
          username: user.username,
          display_name: user.display_name
        }
      },
      posts: posts_data.map { |post|
        {
          id: post.id,
          title: post.title,
          body: post.body,
          author_username: post.user.username,
          author_display_name: post.user.display_name,
          created_at: post.created_at,
          thumbnail_filename: post.thumbnail.attached? ? post.thumbnail.filename.sanitized : nil
        }
      }
    }
  end

  # 画像付きZIPエクスポート（メンバーのみ実行可能）
  def export_with_images_zip
    # 投稿データを一度だけ取得（重複クエリ対策）
    posts_with_includes = published_posts.includes(:user).with_attached_thumbnail.order(created_at: :asc).to_a

    stringio = Zip::OutputStream.write_buffer do |zip|
      # 1. JSON追加（取得済みのpostsデータを再利用）
      zip.put_next_entry("#{slug}_data.json")
      zip.write to_export_json(posts_with_includes: posts_with_includes).to_json

      # 2. カバーアート追加
      if thumbnail.attached?
        zip.put_next_entry("images/thread_thumbnail_#{thumbnail.filename.sanitized}")
        zip.write thumbnail.download
      end

      # 3. 投稿画像追加（既に取得済みのpostsデータを使用）
      posts_with_includes.each do |post|
        if post.thumbnail.attached?
          zip.put_next_entry("images/post_#{post.id}_#{post.thumbnail.filename.sanitized}")
          zip.write post.thumbnail.download
        end
      end
    end

    stringio.string
  end

  # Scopes
  scope :recent_order, -> { order(last_posted_at: :desc, created_at: :desc) }
  scope :public_threads, -> { where(status: [ "free", "paid" ]) }
  scope :discoverable, -> { public_threads.where(show_in_list: true) }
  scope :sample_threads, -> { where(is_sample: true) }
  scope :user_threads, -> { where(is_sample: false) }

  # Associations
  has_many :memberships, foreign_key: :thread_id, dependent: :destroy
  has_many :users, through: :memberships
  has_many :posts, -> { unscope(where: :status) }, foreign_key: :thread_id, dependent: :destroy
  has_many :published_posts, -> { published_posts }, class_name: "Post", foreign_key: :thread_id
  has_many :draft_posts, -> { draft_posts }, class_name: "Post", foreign_key: :thread_id
  has_many :subscriptions, foreign_key: :thread_id, dependent: :destroy
  has_many :subscribers, through: :subscriptions, source: :user
  has_many :skips, foreign_key: :thread_id, dependent: :destroy
  has_many :invitations, foreign_key: :thread_id, dependent: :destroy
  has_one_attached :thumbnail

  # Validations
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true,
    format: { with: /\A[a-z0-9-]+\z/, message: "英数字とハイフンのみ使用できます" },
    length: { in: 3..50 }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :turn_based, inclusion: { in: [ true, false ] }
  validates :thumbnail, content_type: [ "image/png", "image/jpeg", "image/gif", "image/webp" ],
                        size: { less_than: 5.megabytes }
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
