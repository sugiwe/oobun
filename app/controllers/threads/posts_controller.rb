class Threads::PostsController < Threads::ApplicationController
  skip_before_action :require_login, only: [ :show ]
  before_action :set_post, only: [ :show, :edit, :update, :destroy, :publish ]
  before_action :require_membership, only: [ :new, :create, :edit, :update ]
  before_action :require_post_owner, only: [ :edit, :update, :destroy ]
  before_action :require_my_turn, only: [ :new, :create, :publish ]
  before_action :require_my_turn_for_draft, only: [ :edit, :update ]
  before_action :check_post_rate_limit, only: [ :new ]
  around_action :with_user_lock_for_new_post, only: [ :create ]

  def show
    # スレッドの閲覧権限チェック
    unless @thread.viewable_by?(current_user)
      redirect_to root_path, alert: "この交換日記は非公開です"
      return
    end

    # 下書きは本人のみ閲覧可能
    unless @post.published? || (@post.draft? && @post.editable_by?(current_user))
      redirect_to thread_path(@thread.slug), alert: "この投稿は閲覧できません"
      return
    end

    @prev_post = @post.prev
    @next_post = @post.next
    @draft = @thread.draft_for(current_user) if logged_in?
  end

  def new
    # 新フロー: 下書きを作成してeditにリダイレクトする（GETで来た場合の後方互換性）
    find_or_create_draft_and_redirect
  end

  def create
    # draft-first pattern: 常に空の下書きを作成してeditにリダイレクト
    find_or_create_draft_and_redirect
  end

  def edit
    # 下書きまたは公開済み投稿を編集可能
    set_prev_post if @post.draft?
  end

  def update
    @post.thumbnail.purge if params[:post][:remove_thumbnail] == "1"

    respond_to do |format|
      if @post.update(post_params)
        format.html do
          notice = @post.draft? ? "下書きを更新しました" : "投稿を更新しました"
          redirect_path = @post.draft? ? thread_path(@thread.slug) : thread_post_path(@thread.slug, @post)
          redirect_to redirect_path, notice: notice
        end
        format.json { render json: { success: true, message: "自動保存しました" }, status: :ok }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @post.errors.full_messages }, status: :unprocessable_entity }
      end
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

    @post.status = "published"
    if @post.valid?
      ActiveRecord::Base.transaction do
        @post.save!
        @thread.update_last_post_metadata!
      end
      redirect_to thread_post_path(@thread.slug, @post), notice: "投稿しました"
    else
      set_prev_post
      render :edit, status: :unprocessable_entity
    end
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

  def set_prev_post
    # 前回の投稿（最新の公開済み投稿）を取得
    @prev_post = @thread.posts.published
                        .includes(:user, thumbnail_attachment: :blob)
                        .reorder(created_at: :desc)
                        .first
  end

  def check_post_rate_limit
    # 新規投稿のみチェック（既存の下書きの場合はスキップ）
    is_new_post = !@thread.posts.unscope(where: :status).exists?(user: current_user, status: "draft")

    if is_new_post && current_user.post_rate_limit_exceeded?
      redirect_to thread_path(@thread.slug), alert: "投稿が多すぎます。1時間あたり#{User::MAX_POSTS_PER_HOUR}投稿、1日あたり#{User::MAX_POSTS_PER_DAY}投稿まで可能です。しばらく待ってから投稿してください。"
    end
  end

  def with_user_lock_for_new_post
    # 新規投稿の場合のみロック（既存下書きの更新はロック不要）
    is_new_post = !@thread.posts.unscope(where: :status).exists?(user: current_user, status: "draft")

    if is_new_post
      current_user.with_lock do
        # レート制限の最終チェック
        if current_user.post_rate_limit_exceeded?
          redirect_to thread_path(@thread.slug), alert: "投稿が多すぎます。1時間あたり#{User::MAX_POSTS_PER_HOUR}投稿、1日あたり#{User::MAX_POSTS_PER_DAY}投稿まで可能です。しばらく待ってから投稿してください。"
          return
        end
        yield
      end
    else
      yield
    end
  end

  def find_or_create_draft_and_redirect
    @post = @thread.posts.unscope(where: :status)
                         .find_or_create_by!(user: current_user, status: "draft")
    redirect_to edit_thread_post_path(@thread.slug, @post)
  end
end
