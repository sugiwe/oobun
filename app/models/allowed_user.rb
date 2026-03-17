class AllowedUser < ApplicationRecord
  belongs_to :invited_by, class_name: "User", optional: true
  belongs_to :login_invitation, optional: true

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :added_by_admin, -> { where(added_by_admin: true) }
  scope :added_by_invitation, -> { where(added_by_admin: false) }
  scope :contacted, -> { where(contacted: true) }
  scope :not_contacted, -> { where(contacted: false) }

  before_validation :normalize_email

  def added_by
    added_by_admin? ? "管理者" : "招待 (#{invited_by&.display_name})"
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end
end
