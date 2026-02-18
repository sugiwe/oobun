class ThreadsController < ApplicationController
  skip_before_action :require_login, only: [:index, :show]
  before_action :set_thread, only: [:show, :edit, :update]
  before_action :require_membership, only: [:edit, :update]

  def index
    @threads = Thread.includes(:users, :memberships)
                     .where(visibility: "public")
                     .order(last_posted_at: :desc, created_at: :desc)
  end

  def show
    @posts = @thread.posts.includes(:user)
    @members = @thread.memberships.includes(:user).order(:position)
  end

  def new
    @thread = Thread.new
  end

  def create
    @thread = Thread.new(thread_params)

    Thread.transaction do
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
    @thread = Thread.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "スレッドが見つかりません"
  end

  def require_membership
    unless @thread.memberships.exists?(user: current_user)
      redirect_to thread_path(@thread.slug), alert: "権限がありません"
    end
  end

  def thread_params
    params.require(:thread).permit(:title, :slug, :description, :visibility, :turn_based)
  end
end
