class Invitation < ApplicationRecord
  belongs_to :thread, class_name: "CorrespondenceThread", foreign_key: :thread_id
  belongs_to :invited_by, class_name: "User"

  before_validation :generate_token, on: :create
  before_validation :set_expiry, on: :create

  validates :token, presence: true, uniqueness: true
  validates :invitation_type, presence: true, inclusion: { in: %w[single_use unlimited] }
  validates :expiry_type, presence: true, inclusion: { in: %w[seven_days unlimited] }

  # Enum definitions
  enum :invitation_type, {
    single_use: "single_use",  # 1回限り
    unlimited: "unlimited"     # 無制限
  }, prefix: true

  enum :expiry_type, {
    seven_days: "seven_days",  # 7日間
    unlimited: "unlimited"     # 無制限
  }, prefix: true

  scope :active, -> { where("expires_at > ? OR expires_at IS NULL", Time.current) }

  def accepted?
    # single_use の場合は accepted_at の有無で判定（後方互換性）
    # unlimited の場合は常に false
    invitation_type_single_use? && accepted_at.present?
  end

  def expired?
    return false if expiry_type_unlimited?
    expires_at < Time.current
  end

  def usable?
    return false if expired?
    return false if invitation_type_single_use? && use_count > 0
    true
  end

  def accept!(user)
    return false unless usable?
    return false if thread.memberships.exists?(user: user)

    ActiveRecord::Base.transaction do
      next_position = thread.memberships.maximum(:position).to_i + 1
      thread.memberships.create!(user: user, position: next_position, role: "member")

      # 使用回数をアトミックにインクリメント
      increment!(:use_count)

      # 日時関連の更新を1つのクエリにまとめる
      updates = { last_used_at: Time.current }
      updates[:accepted_at] = Time.current if invitation_type_single_use?
      update!(updates)
    end
    true
  end

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end

  def set_expiry
    if expiry_type_unlimited?
      self.expires_at = nil
    else
      self.expires_at = 7.days.from_now
    end
  end
end
