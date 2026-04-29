class Threads::Posts::AnnotationsController < Threads::ApplicationController
  before_action :set_post
  before_action :check_post_viewability
  before_action :set_annotation, only: [ :update, :destroy ]
  before_action :require_annotation_owner, only: [ :update, :destroy ]

  def create
    @annotation = @post.annotations.build(annotation_params)
    @annotation.user = current_user

    @annotation.save!

    # 通知を作成（失敗しても付箋は作成済み）
    if @annotation.visibility_public_visible? && @annotation.user_id != @post.user_id
      notify_post_author
    end

    render json: {
      success: true,
      message: "付箋を追加しました",
      annotation: annotation_json(@annotation)
    }, status: :created
  rescue ActiveRecord::RecordInvalid
    render json: {
      success: false,
      errors: @annotation.errors.full_messages
    }, status: :unprocessable_entity
  end

  def update
    # 可視性が変更される場合の処理
    visibility_changed = annotation_params[:visibility].present? &&
                         annotation_params[:visibility] != @annotation.visibility

    @annotation.update!(annotation_params)

    # 通知を作成（失敗しても付箋は更新済み）
    # self_only → public に変更された場合、投稿者に通知
    if visibility_changed && @annotation.visibility_public_visible? && @annotation.user_id != @post.user_id
      notify_post_author
    end

    render json: {
      success: true,
      message: "付箋を更新しました",
      annotation: annotation_json(@annotation)
    }, status: :ok
  rescue ActiveRecord::RecordInvalid
    render json: {
      success: false,
      errors: @annotation.errors.full_messages
    }, status: :unprocessable_entity
  end

  def destroy
    @annotation.destroy!

    render json: {
      success: true,
      message: "付箋を削除しました"
    }, status: :ok
  rescue ActiveRecord::ActiveRecordError
    render json: {
      success: false,
      message: "付箋の削除に失敗しました"
    }, status: :unprocessable_entity
  end

  private

  def set_post
    # 数値IDまたはslugで検索（PostsControllerと同じロジック）
    # 下書きにも付箋をつけられる（編集時に無効化されるが、ユーザーが学習する）
    if params[:post_id].match?(/\A\d+\z/)
      # 数値IDの場合
      @post = @thread.posts.unscope(where: :status).find(params[:post_id])
    else
      # slugの場合
      @post = @thread.posts.unscope(where: :status).find_by!(slug: params[:post_id])
    end
  end

  # 投稿への付箋作成権限をチェック
  def check_post_viewability
    # スレッドの閲覧権限チェック
    unless @thread.viewable_by?(current_user)
      render json: {
        success: false,
        message: "この投稿には付箋を追加できません"
      }, status: :forbidden
      return
    end

    # 下書きは本人のみアクセス可能
    if @post.draft? && @post.user_id != current_user.id
      render json: {
        success: false,
        message: "この投稿には付箋を追加できません"
      }, status: :forbidden
    end
  end

  def set_annotation
    @annotation = @post.annotations.find(params[:id])
  end

  def require_annotation_owner
    unless @annotation.user_id == current_user.id
      render json: {
        success: false,
        message: "この操作は許可されていません"
      }, status: :forbidden
    end
  end

  def annotation_params
    params.require(:annotation).permit(
      :selected_text,
      :body,
      :visibility,
      :paragraph_index
    )
  end

  def annotation_json(annotation)
    {
      id: annotation.id,
      post_id: annotation.post_id,
      user_id: annotation.user_id,
      user: {
        display_name: annotation.user_display_name,
        avatar_url: annotation.user_avatar_url
      },
      paragraph_index: annotation.paragraph_index,
      selected_text: annotation.selected_text,
      body: annotation.body,
      visibility: annotation.visibility,
      icon: annotation.icon,
      marker_color_class: annotation.marker_color_class,
      created_at: annotation.created_at.iso8601,
      updated_at: annotation.updated_at.iso8601
    }
  end

  def notify_post_author
    # 投稿者に通知を作成
    # annotation_preview: 付箋の内容のプレビュー（最初の50文字）
    annotation_preview = @annotation.body.truncate(50, omission: "...")

    @post.user.notifications.create!(
      actor: current_user,
      notifiable: @annotation,
      action: :annotation_added,
      params: {
        annotation_preview: annotation_preview,
        post_title: @post.title,
        thread_title: @post.thread.title
      }
    )
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    # 通知失敗をログに記録（付箋作成は成功させる）
    Rails.logger.error("Failed to create notification for annotation #{@annotation.id}: #{e.message}")
    # 通知失敗は付箋作成に影響させない（Graceful Degradation）
  end
end
