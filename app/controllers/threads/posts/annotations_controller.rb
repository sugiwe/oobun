class Threads::Posts::AnnotationsController < Threads::ApplicationController
  before_action :set_post
  before_action :set_annotation, only: [ :update, :destroy ]
  before_action :require_annotation_owner, only: [ :update, :destroy ]

  def create
    @annotation = @post.annotations.build(annotation_params)
    @annotation.user = current_user

    if @annotation.save
      # 公開付箋の場合、投稿者に通知
      if @annotation.public? && @annotation.user_id != @post.user_id
        notify_post_author
      end

      render json: {
        success: true,
        message: "マーカー・付箋を追加しました",
        annotation: annotation_json(@annotation)
      }, status: :created
    else
      render json: {
        success: false,
        errors: @annotation.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def update
    # 可視性が変更される場合の処理
    visibility_changed = annotation_params[:visibility].present? &&
                         annotation_params[:visibility] != @annotation.visibility

    if @annotation.update(annotation_params)
      # self_only → public に変更された場合、投稿者に通知
      if visibility_changed && @annotation.public? && @annotation.user_id != @post.user_id
        notify_post_author
      end

      render json: {
        success: true,
        message: "マーカー・付箋を更新しました",
        annotation: annotation_json(@annotation)
      }, status: :ok
    else
      render json: {
        success: false,
        errors: @annotation.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def destroy
    @annotation.destroy!

    render json: {
      success: true,
      message: "マーカー・付箋を削除しました"
    }, status: :ok
  rescue ActiveRecord::ActiveRecordError
    render json: {
      success: false,
      message: "マーカー・付箋の削除に失敗しました"
    }, status: :unprocessable_entity
  end

  private

  def set_post
    @post = @thread.posts.find_by!(slug: params[:post_id]) ||
            @thread.posts.find(params[:post_id])
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
      :start_offset,
      :end_offset,
      :selected_text,
      :body,
      :visibility
    )
  end

  def annotation_json(annotation)
    {
      id: annotation.id,
      post_id: annotation.post_id,
      user_id: annotation.user_id,
      user_name: annotation.user.display_name,
      start_offset: annotation.start_offset,
      end_offset: annotation.end_offset,
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
    @post.user.notifications.create!(
      actor: current_user,
      notifiable: @annotation,
      action: :annotation_added
    )
  end
end
