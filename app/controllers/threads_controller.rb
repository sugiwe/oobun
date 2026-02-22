class ThreadsController < ApplicationController
  skip_before_action :require_login, only: [ :index, :show ]
  before_action :set_thread, only: [ :show, :edit, :update ]
  before_action :require_membership, only: [ :edit, :update ]

  def index
    base_query = CorrespondenceThread.includes(:users, :memberships)
                                     .where(visibility: "public")

    if logged_in?
      @subscribed_threads = current_user.subscribed_threads.merge(base_query).order(last_posted_at: :desc, created_at: :desc)
      @other_threads = base_query.where.not(id: @subscribed_threads).order(last_posted_at: :desc, created_at: :desc)
    else
      @threads = base_query.order(last_posted_at: :desc, created_at: :desc)
    end
  end

  def show
    unless can_view_thread?(@thread)
      redirect_to root_path, alert: "アクセス権限がありません"
      return
    end

    @posts = @thread.posts.includes(:user).reorder(created_at: :desc)
    @members = @thread.memberships.includes(:user).order(:position)

    respond_to do |format|
      format.html
      format.rss { render layout: false }
    end
  end

  def new
    @thread = CorrespondenceThread.new
  end

  def create
    @thread = CorrespondenceThread.new(thread_params)

    ActiveRecord::Base.transaction do
      @thread.save!
      @thread.memberships.create!(user: current_user, position: 1, role: "writer")
    end

    redirect_to thread_path(@thread.slug), notice: "スレッドを作成しました"
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    if @thread.update(thread_params)
      redirect_to thread_path(@thread.slug), notice: "スレッドを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_thread
    @thread = CorrespondenceThread.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "スレッドが見つかりません"
  end

  def require_membership
    unless @thread.memberships.exists?(user: current_user)
      redirect_to thread_path(@thread.slug), alert: "権限がありません"
    end
  end

  def can_view_thread?(thread)
    # Phase 1: public のみ閲覧可能
    return true if thread.visibility == "public"

    # Phase 3 で追加予定の visibility:
    # - url_only: URL を知っていれば誰でも閲覧可能
    #   return true if thread.visibility == "url_only"
    #
    # - followers_only / paid: メンバーのみ閲覧可能
    #   return true if logged_in? && thread.memberships.exists?(user: current_user)

    false
  end

  def thread_params
    params.require(:thread).permit(:title, :slug, :description, :visibility, :turn_based)
  end
end
