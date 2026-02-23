class Threads::PostsController < Threads::ApplicationController
  skip_before_action :require_login, only: [ :show ]
  before_action :set_post, only: [ :show ]
  before_action :require_membership, only: [ :new, :create ]
  before_action :require_my_turn, only: [ :new, :create ]

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

  private

  def set_post
    @post = @thread.posts.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to thread_path(@thread.slug), alert: "投稿が見つかりません"
  end

  def post_params
    params.require(:post).permit(:title, :body)
  end
end
