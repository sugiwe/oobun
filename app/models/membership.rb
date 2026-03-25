class Membership < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :thread, class_name: "CorrespondenceThread", foreign_key: :thread_id

  # Role enum
  enum :role, {
    member: "member",      # 参加者（投稿のみ）
    moderator: "moderator", # 管理者（メンバー管理、設定変更、招待権限）
    owner: "owner"         # オーナー（全権限、脱退不可）
  }

  # Validations
  validates :position, presence: true, uniqueness: { scope: :thread_id }
  validates :role, presence: true, inclusion: { in: roles.keys }
  validates :user_id, uniqueness: { scope: :thread_id, message: "はすでにこのスレッドのメンバーです" }

  # 権限チェックメソッド
  def can_invite?
    moderator? || owner?
  end

  def can_manage_members?
    moderator? || owner?
  end

  def can_edit_settings?
    moderator? || owner?
  end

  def can_delete_thread?
    owner?
  end

  def can_promote_to_moderator?
    owner?
  end

  def can_leave?
    !owner?  # オーナーは脱退不可
  end
end
