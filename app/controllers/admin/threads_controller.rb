class Admin::ThreadsController < Admin::ApplicationController
  # GET /admin/threads
  def index
    # 最終投稿日時順でソート（最新順）
    @threads = CorrespondenceThread
                 .includes(memberships: :user, posts: :user)
                 .order(Arel.sql("COALESCE((SELECT MAX(posts.created_at) FROM posts WHERE posts.thread_id = threads.id), threads.created_at) DESC"))
                 .page(params[:page])
  end

  # GET /admin/threads/:id
  def show
    @thread = CorrespondenceThread.find(params[:id])
    @memberships = @thread.memberships.includes(:user).order(:position)
    @posts_count = @thread.posts.count
    @first_post_at = @thread.posts.order(:created_at).first&.created_at
    @last_post_at = @thread.posts.order(:created_at).last&.created_at
  end
end
