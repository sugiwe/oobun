class User < ApplicationRecord
  # Associations
  has_many :memberships, dependent: :destroy
  has_many :correspondence_threads, through: :memberships, source: :thread
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
  validates :google_uid, uniqueness: true, allow_nil: true

  # Google OAuth ログイン用クラスメソッド
  def self.find_or_initialize_from_google(payload)
    find_or_initialize_by(google_uid: payload["sub"]).tap do |user|
      user.email        = payload["email"]
      user.display_name = payload["name"]
      user.avatar_url   = payload["picture"]
      # username は新規ユーザーの場合のみ未設定のまま（別画面で設定）
    end
  end
end
