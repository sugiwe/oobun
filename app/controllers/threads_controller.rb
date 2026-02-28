class ThreadsController < ApplicationController
  skip_before_action :require_login, only: [ :index, :show, :browse ]
  before_action :set_thread, only: [ :show, :edit, :update, :destroy ]
  before_action :require_membership, only: [ :edit, :update, :destroy ]

  def index
    if logged_in?
      # パーソナライズドフィード（ログイン時）
      build_personalized_feed
    else
      # ランディングページ（ログアウト時）
      @threads = CorrespondenceThread.includes(:users, :memberships)
                                     .where(visibility: "public")
                                     .recent_order
                                     .limit(6)
    end
  end

  def browse
    # 全スレッド一覧ページ
    @threads = CorrespondenceThread.includes(:users, :memberships)
                                   .where(visibility: "public")
                                   .recent_order
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
    # 新しいカバーアートがアップロードされていない場合のみ削除チェックを処理
    should_remove_thumbnail = params.dig(:thread, :remove_thumbnail) == "1" &&
                              thread_params[:thumbnail].blank?

    if @thread.update(thread_params)
      @thread.thumbnail.purge if should_remove_thumbnail
      redirect_to thread_path(@thread.slug), notice: "スレッドを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @thread.destroy!
    redirect_to root_path, notice: "スレッドを削除しました"
  rescue ActiveRecord::ActiveRecordError
    redirect_to thread_path(@thread.slug), alert: "スレッドの削除に失敗しました"
  end

  private

  def build_personalized_feed
    # 1. 自分のターンのスレッド → 相手の最後の投稿を取得
    my_turn_threads = current_user.correspondence_threads
                                   .where(turn_based: true, visibility: "public")
                                   .select { |t| t.my_turn?(current_user) }

    # 各スレッドの最後の投稿を取得（相手からの投稿）
    my_turn_thread_ids = my_turn_threads.map(&:id)
    @my_turn_posts = Post.includes(:user, :thread)
                         .where(thread_id: my_turn_thread_ids)
                         .group_by(&:thread_id)
                         .map { |thread_id, posts| posts.max_by(&:created_at) }
                         .compact
                         .sort_by(&:created_at)
                         .reverse

    # 2. 参加中のスレッド
    @participated_threads = current_user.correspondence_threads
                                        .includes(:users, :memberships)
                                        .where(visibility: "public")
                                        .recent_order

    # 3. フォロー中のスレッド（参加中を除く）
    participated_ids = @participated_threads.pluck(:id)
    @followed_threads = current_user.subscribed_threads
                                    .includes(:users, :memberships)
                                    .where(visibility: "public")
                                    .where.not(id: participated_ids)
                                    .recent_order

    # 4. フォロー中スレッドの新着投稿（10件）
    followed_thread_ids = current_user.subscribed_threads.pluck(:id)
    @recent_posts = Post.includes(:user, :thread)
                        .where(thread_id: followed_thread_ids)
                        .reorder(created_at: :desc)
                        .limit(10)
  end

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
    params.require(:thread).permit(:title, :slug, :description, :visibility, :turn_based, :thumbnail)
  end
end
