# == Schema Information
#
# Table name: annotations
#
#  id                   :bigint           not null, primary key
#  body                 :text             not null
#  invalidated_at       :datetime
#  invalidation_reason  :string
#  paragraph_index      :integer
#  selected_text        :text             not null
#  visibility           :string           default("self_only"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  post_id              :bigint           not null
#  user_id              :bigint           not null
#
# Indexes
#
#  index_annotations_on_post_id              (post_id)
#  index_annotations_on_post_id_and_created_at  (post_id,created_at)
#  index_annotations_on_user_id              (user_id)
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
  validates :selected_text, presence: true,
                            length: { minimum: 1, maximum: 1000 }
  validates :body, presence: true,
                   length: { minimum: 1, maximum: 1000 }
  validates :visibility, presence: true,
                         inclusion: { in: visibilities.keys }
  validates :paragraph_index, presence: true,
                              numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # カスタムバリデーション: 段落を跨いでいないかチェック
  validate :selection_within_single_paragraph
  # カスタムバリデーション: paragraph_indexが投稿の段落数を超えていないかチェック
  validate :paragraph_index_within_range

  # スコープ
  scope :active, -> { where(invalidated_at: nil) }
  scope :invalidated, -> { where.not(invalidated_at: nil) }

  scope :visible_to, ->(user) {
    if user
      visibility_public_visible.or(where(user_id: user.id))
    else
      visibility_public_visible  # 未ログインユーザーには公開付箋のみ表示
    end
  }

  scope :public_only, -> { visibility_public_visible }
  scope :by_user, ->(user) { where(user_id: user.id) }

  # 可視性チェックメソッド
  def visible_to?(current_user)
    return visibility_public_visible? if current_user.nil?

    visibility_public_visible? || (visibility_self_only? && user_id == current_user.id)
  end

  # 付箋の背景色を返す（CSS クラス用）
  def marker_color_class
    visibility_self_only? ? "bg-blue-100" : "bg-yellow-100"
  end

  # 付箋のアイコンを返す
  def icon
    visibility_self_only? ? "🔒" : "🌐"
  end

  # 無効化されているかどうか
  def invalidated?
    invalidated_at.present?
  end

  # 有効かどうか
  def active?
    invalidated_at.nil?
  end

  # ユーザーのアバターURLを返す（JSON用）
  def user_avatar_url
    if user.avatar.attached?
      Rails.application.routes.url_helpers.rails_blob_path(user.avatar, only_path: true)
    elsif user.avatar_url.present?
      user.avatar_url
    else
      nil
    end
  end

  # ユーザーの表示名を返す（JSON用）
  def user_display_name
    user.display_name
  end

  private

  def selection_within_single_paragraph
    return unless post&.body && selected_text.present?

    # 選択されたテキストに段落区切り（\n\n）が含まれていないかチェック
    # Markdown では段落は空行（\n\n）で区切られるため、この単純なチェックで十分
    # より複雑な正規表現（例: /\n\s*\n/）も考えられるが、
    # 本アプリでは実際のテキストマッチングに影響するため、シンプルな "\n\n" を使用
    if selected_text.include?("\n\n")
      errors.add(:selected_text, "は段落を跨いで選択できません。1つの段落内で選択してください。")
    end
  end

  def paragraph_index_within_range
    return unless paragraph_index.present? && post&.body.present?

    # ブロック要素数を計算（フロントエンドと同じロジック）
    block_count = count_markdown_blocks(post.body)

    if paragraph_index >= block_count
      errors.add(:paragraph_index, "が投稿の段落数を超えています")
    end
  end

  # Markdownをレンダリングしてブロック要素数をカウント
  # フロントエンドのJavaScriptと同じロジック:
  # querySelectorAll("p, h1, h2, h3, h4, h5, h6, ul:not(ul ul):not(ol ul), ol:not(ul ol):not(ol ol), blockquote, pre")
  def count_markdown_blocks(markdown_text)
    return 0 if markdown_text.blank?

    # Redcarpetでレンダリング（MarkdownHelperと同じ設定）
    renderer = Redcarpet::Render::HTML.new(
      filter_html: false,
      no_images: false,
      no_links: false,
      hard_wrap: true
    )

    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      space_after_headers: true,
      fenced_code_blocks: true,
      strikethrough: true,
      superscript: true
    )

    html = markdown.render(markdown_text)

    # NokogiriでHTMLをパース
    doc = Nokogiri::HTML.fragment(html)

    # フロントエンドと同じセレクタでブロック要素をカウント
    # - p, h1-h6, blockquote, pre は直接カウント
    # - ul/ol は最上位のもののみ（ネストした子リストは除外）
    block_elements = doc.css("p, h1, h2, h3, h4, h5, h6, blockquote, pre")

    # 最上位のul/olを追加（先祖要素にul/olがあればネストとみなす）
    top_level_lists = doc.css("ul, ol").select do |list|
      # 先祖要素にul/olが存在しない場合のみ最上位リストとみなす
      list.ancestors("ul, ol").empty?
    end

    block_elements.count + top_level_lists.count
  end
end
