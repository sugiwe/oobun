class Threads::PostsController < Threads::ApplicationController
  skip_before_action :require_login, only: [ :show ]
  before_action :set_post, only: [ :show, :edit, :update, :destroy ]
  before_action :require_membership, only: [ :new, :create ]
  before_action :require_my_turn, only: [ :new, :create ]
  before_action :require_post_owner, only: [ :edit, :update, :destroy ]

  def show
    @prev_post = @post.prev
    @next_post = @post.next
  end

  def new
    @post = Post.new
  end

  def create
    @post = @thread.posts.build(post_params.merge(user: current_user))

    if @post.save
      @thread.update!(
        last_post_user_id: current_user.id,
        last_posted_at: @post.created_at
      )
      redirect_to thread_post_path(@thread.slug, @post), notice: "投稿しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @post.update(post_params)
      redirect_to thread_post_path(@thread.slug, @post), notice: "投稿を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    ActiveRecord::Base.transaction do
      @post.destroy!
      last_post = @thread.posts.where.not(id: @post.id).reorder(created_at: :desc).first
      @thread.update!(
        last_post_user_id: last_post&.user_id,
        last_posted_at: last_post&.created_at
      )
    end
    redirect_to thread_path(@thread.slug), notice: "投稿を削除しました"
  rescue ActiveRecord::ActiveRecordError
    redirect_to thread_post_path(@thread.slug, @post), alert: "投稿の削除に失敗しました"
  end

  private

  def set_post
    @post = @thread.posts.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to thread_path(@thread.slug), alert: "投稿が見つかりません"
  end

  def post_params
    params.require(:post).permit(:title, :body, :thumbnail)
  end

  def require_post_owner
    unless @post.editable_by?(current_user)
      redirect_to thread_post_path(@thread.slug, @post), alert: "自分の投稿のみ操作できます"
    end
  end
end
