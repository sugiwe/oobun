class Invitation < ApplicationRecord
  belongs_to :thread, class_name: "CorrespondenceThread", foreign_key: :thread_id
  belongs_to :invited_by, class_name: "User"

  before_validation :generate_token, on: :create
  before_validation :set_expiry, on: :create

  validates :token, presence: true, uniqueness: true

  scope :active, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }

  def accepted?
    accepted_at.present?
  end

  def expired?
    expires_at < Time.current
  end

  def usable?
    !accepted? && !expired?
  end

  def accept!(user)
    return false if accepted? || expired?
    return false if thread.memberships.exists?(user: user)

    ActiveRecord::Base.transaction do
      next_position = thread.memberships.maximum(:position).to_i + 1
      thread.memberships.create!(user: user, position: next_position, role: "member")
      update!(accepted_at: Time.current)
    end
    true
  end

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end

  def set_expiry
    self.expires_at = 7.days.from_now
  end
end
