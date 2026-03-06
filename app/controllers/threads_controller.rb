class ThreadsController < ApplicationController
  skip_before_action :require_login, only: [ :index, :show, :browse ]
  before_action :set_thread, only: [ :show, :edit, :update, :destroy, :toggle_published ]
  before_action :require_membership, only: [ :edit, :update, :destroy, :toggle_published ]
  before_action :require_viewable, only: [ :show ]

  def index
    if logged_in?
      # パーソナライズドフィード（ログイン時）
      build_personalized_feed
    else
      # ランディングページ（ログアウト時）
      @threads = CorrespondenceThread.public_threads
                                     .includes(:users, :memberships)
                                     .recent_order
                                     .limit(6)
    end
  end

  def browse
    # 全交換日記一覧ページ
    @threads = CorrespondenceThread.public_threads
                                   .includes(:users, :memberships)
                                   .recent_order
  end

  def show
    @posts = @thread.visible_posts_for(current_user).includes(:user).reorder(created_at: :desc)
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
    unless current_user.can_join_thread?
      redirect_to new_thread_path, alert: "参加できる交換日記の上限（#{User::MAX_THREADS_PER_USER}個）に達しています。他の交換日記を削除してから作成してください。"
      return
    end

    @thread = CorrespondenceThread.new(thread_params)

    ActiveRecord::Base.transaction do
      @thread.save!
      @thread.memberships.create!(user: current_user, position: 1, role: "writer")
    end

    redirect_to thread_path(@thread.slug), notice: "交換日記を作成しました"
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    # 新しいカバーアートがアップロードされていない場合のみ削除チェックを処理
    should_remove_thumbnail = params.dig(:thread, :remove_thumbnail) == "1" &&
                              thread_params[:thumbnail].blank?

    if @thread.update(thread_params)
      @thread.thumbnail.purge if should_remove_thumbnail
      redirect_to thread_path(@thread.slug), notice: "交換日記を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @thread.destroy!
    redirect_to root_path, notice: "交換日記を削除しました"
  rescue ActiveRecord::RecordNotDestroyed
    redirect_to thread_path(@thread.slug), alert: "交換日記の削除に失敗しました"
  end

  def toggle_published
    @thread.toggle_published!
    state = @thread.draft? ? "非公開" : "公開"
    redirect_to thread_path(@thread.slug), notice: "交換日記を#{state}にしました"
  rescue ActiveRecord::RecordInvalid
    redirect_to thread_path(@thread.slug), alert: "公開状態の変更に失敗しました"
  end

  private

  def build_personalized_feed
    feed_data = current_user.personalized_feed_data
    @my_turn_posts = feed_data[:my_turn_posts]
    @participated_threads = feed_data[:participated_threads]
    @followed_threads = feed_data[:followed_threads]
    @recent_posts = feed_data[:recent_posts]
  end

  def set_thread
    @thread = CorrespondenceThread.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "交換日記が見つかりません"
  end

  def require_membership
    unless @thread.memberships.exists?(user: current_user)
      redirect_to thread_path(@thread.slug), alert: "権限がありません"
    end
  end

  def require_viewable
    unless @thread.viewable_by?(current_user)
      redirect_to root_path, alert: "この交換日記は非公開です"
    end
  end

  def thread_params
    params.require(:thread).permit(:title, :slug, :description, :status, :turn_based, :thumbnail)
  end
end
