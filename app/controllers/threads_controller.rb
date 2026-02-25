class ThreadsController < ApplicationController
  skip_before_action :require_login, only: [ :index, :show ]
  before_action :set_thread, only: [ :show, :edit, :update, :destroy ]
  before_action :require_membership, only: [ :edit, :update, :destroy ]

  def index
    base_query = CorrespondenceThread.includes(:users, :memberships)
                                     .where(visibility: "public")
                                     .recent_order

    if logged_in?
      @subscribed_threads = current_user.subscribed_threads.merge(base_query)
      @other_threads = base_query.where.not(id: @subscribed_threads)
    else
      @threads = base_query
    end
  end

  def show
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

  def destroy
    @thread.destroy!
    redirect_to root_path, notice: "スレッドを削除しました"
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

  def thread_params
    params.require(:thread).permit(:title, :slug, :description, :visibility, :turn_based)
  end
end
