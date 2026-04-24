# == Schema Information
#
# Table name: annotations
#
#  id            :bigint           not null, primary key
#  body          :text             not null
#  end_offset    :integer          not null
#  selected_text :text             not null
#  start_offset  :integer          not null
#  visibility    :string           default("self_only"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  post_id       :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_annotations_on_post_id_and_created_at  (post_id,created_at)
#  index_annotations_on_user_id_and_created_at  (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (post_id => posts.id)
#  fk_rails_...  (user_id => users.id)
#
class Annotation < ApplicationRecord
  belongs_to :post
  belongs_to :user

  # 可視性の設定
  enum :visibility, {
    self_only: "self_only",       # 自分だけのメモ（デフォルト）
    public_visible: "public"      # 公開する（誰でも見られる）
  }, default: :self_only, prefix: true

  # バリデーション
  validates :start_offset, presence: true,
                           numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :end_offset, presence: true,
                         numericality: { only_integer: true, greater_than: :start_offset }
  validates :selected_text, presence: true,
                            length: { minimum: 1, maximum: 300 }
  validates :body, presence: true,
                   length: { minimum: 1, maximum: 1000 }
  validates :visibility, presence: true,
                         inclusion: { in: visibilities.keys }

  # カスタムバリデーション: 段落を跨いでいないかチェック
  validate :selection_within_single_paragraph

  # スコープ
  scope :visible_to, ->(user) {
    return none unless user

    visibility_public_visible
      .or(where(user_id: user.id))
  }

  scope :public_only, -> { visibility_public_visible }
  scope :by_user, ->(user) { where(user_id: user.id) }

  # 可視性チェックメソッド
  def visible_to?(current_user)
    return false unless current_user

    visibility_public_visible? || (visibility_self_only? && user_id == current_user.id)
  end

  # マーカーの色を返す（CSS クラス用）
  def marker_color_class
    visibility_self_only? ? "bg-blue-100" : "bg-yellow-100"
  end

  # 付箋のアイコンを返す
  def icon
    visibility_self_only? ? "🔒" : "🌐"
  end

  private

  def selection_within_single_paragraph
    return unless post&.body && selected_text.present?

    # 選択されたテキストに段落区切り（\n\n）が含まれていないかチェック
    if selected_text.include?("\n\n")
      errors.add(:selected_text, "は段落を跨いで選択できません。1つの段落内で選択してください。")
    end
  end
end
