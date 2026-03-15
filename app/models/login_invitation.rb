class LoginInvitation < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  has_many :allowed_users, dependent: :nullify

  before_validation :generate_token, on: :create
  before_validation :set_expiry, on: :create

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  def used?
    used_at.present?
  end

  def expired?
    expires_at < Time.current
  end

  def usable?
    !expired? && (unlimited? || !used?)
  end

  def mark_as_used!
    return if unlimited?  # 無制限の場合は使用済みにしない
    update!(used_at: Time.current)
  end

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end

  def set_expiry
    self.expires_at = 7.days.from_now
  end
end
