class Threads::PostsController < Threads::ApplicationController
  skip_before_action :require_login, only: [ :show ]
  before_action :set_post, only: [ :show, :edit, :update, :destroy, :publish ]
  before_action :require_membership, only: [ :new, :create, :edit, :update ]
  before_action :require_post_owner, only: [ :edit, :update, :destroy ]
  before_action :require_my_turn, only: [ :new, :create, :publish ]
  before_action :require_my_turn_for_draft, only: [ :edit, :update ]

  def show
    # 下書きは本人のみ閲覧可能
    unless @post.published? || (@post.draft? && @post.editable_by?(current_user))
      redirect_to thread_path(@thread.slug), alert: "この投稿は閲覧できません"
      return
    end

    @prev_post = @post.prev
    @next_post = @post.next
  end

  def new
    # 既存の下書きがあればそれを使う、なければ新規作成
    @post = @thread.posts.unscope(where: :status)
                         .draft_posts
                         .find_or_initialize_by(user: current_user)

    # 前回の投稿（最新の公開済み投稿）を取得
    @prev_post = @thread.posts.published
                        .includes(:user, thumbnail_attachment: :blob)
                        .reorder(created_at: :desc)
                        .first
  end

  def create
    @post = @thread.posts.unscope(where: :status)
                         .find_or_initialize_by(user: current_user, status: "draft")

    # ボタンの種類で処理を分岐
    if params[:commit] == "投稿する"
      # 直接公開
      ActiveRecord::Base.transaction do
        @post.assign_attributes(post_params.merge(status: "published"))
        @post.save!
        @thread.update_last_post_metadata!
      end
      redirect_to thread_post_path(@thread.slug, @post), notice: "投稿しました"
    else
      # 下書き保存
      if @post.update(post_params.merge(status: "draft"))
        redirect_to thread_path(@thread.slug), notice: "下書きを保存しました"
      else
        render :new, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
    # 下書きまたは公開済み投稿を編集可能
  end

  def update
    @post.thumbnail.purge if params[:post][:remove_thumbnail] == "1"

    if @post.update(post_params)
      notice = @post.draft? ? "下書きを更新しました" : "投稿を更新しました"
      redirect_path = @post.draft? ? thread_path(@thread.slug) : thread_post_path(@thread.slug, @post)
      redirect_to redirect_path, notice: notice
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    is_draft = @post.draft?

    ActiveRecord::Base.transaction do
      @post.destroy!
      @thread.update_last_post_metadata!(excluded_post_id: @post.id) unless is_draft
    end

    notice = is_draft ? "下書きを削除しました" : "投稿を削除しました"
    redirect_to thread_path(@thread.slug), notice: notice
  rescue ActiveRecord::ActiveRecordError
    alert = is_draft ? "下書きの削除に失敗しました" : "投稿の削除に失敗しました"
    redirect_to thread_path(@thread.slug), alert: alert
  end

  def publish
    unless @post.can_publish?(current_user)
      redirect_to thread_path(@thread.slug), alert: "この下書きは公開できません"
      return
    end

    ActiveRecord::Base.transaction do
      @post.publish!
      @thread.update_last_post_metadata!
    end

    redirect_to thread_post_path(@thread.slug, @post), notice: "投稿しました"
  rescue ActiveRecord::RecordInvalid
    redirect_to edit_thread_post_path(@thread.slug, @post), alert: "投稿に失敗しました"
  end

  private

  def set_post
    @post = @thread.posts.unscope(where: :status).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to thread_path(@thread.slug), alert: "投稿が見つかりません"
  end

  def post_params
    params.require(:post).permit(:title, :body, :thumbnail)
  end

  def require_post_owner
    unless @post.editable_by?(current_user)
      redirect_to thread_path(@thread.slug), alert: "自分の投稿のみ操作できます"
    end
  end

  def require_my_turn_for_draft
    return unless @post.draft?
    unless @thread.my_turn?(current_user)
      redirect_to thread_path(@thread.slug), alert: "今はあなたのターンではありません"
    end
  end
end
