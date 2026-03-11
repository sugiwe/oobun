class ThreadsController < ApplicationController
  skip_before_action :require_login, only: [ :index, :show, :browse ]
  before_action :set_thread, only: [ :show, :edit, :update, :destroy, :toggle_published, :export, :export_with_images ]
  before_action :require_membership, only: [ :edit, :update, :destroy, :toggle_published, :export, :export_with_images ]
  before_action :require_viewable, only: [ :show ]

  # 画像付きエクスポートのレート制限（DoS対策）
  rate_limit to: 3, within: 1.hour, only: :export_with_images, by: -> { current_user.id }

  # レート制限エラーハンドリング
  rescue_from ActionController::TooManyRequests do |exception|
    redirect_to thread_path(params[:slug]), alert: "画像付きエクスポートは1時間に3回までです。しばらくお待ちください。"
  end

  def index
    if logged_in?
      # パーソナライズドフィード（ログイン時）
      build_personalized_feed
    else
      # ランディングページ（ログアウト時）
      @threads = CorrespondenceThread.discoverable
                                     .includes(:users, :memberships)
                                     .recent_order
                                     .limit(6)
    end
  end

  def browse
    # 全交換日記一覧ページ
    @threads = CorrespondenceThread.discoverable
                                   .includes(:users, :memberships)
                                   .recent_order
                                   .page(params[:page])
  end

  def show
    # ソート順（デフォルトは新しい順）
    @current_sort = params[:sort] == "oldest" ? "oldest" : "newest"
    order_direction = @current_sort == "oldest" ? :asc : :desc
    @posts = @thread.visible_posts_for(current_user)
                    .includes(:user)
                    .reorder(created_at: order_direction)
                    .page(params[:page])
                    .per(10)
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
      # 競合状態を防ぐためにユーザーレコードをロック
      current_user.lock!
      unless current_user.can_join_thread?
        redirect_to new_thread_path, alert: "参加できる交換日記の上限（#{User::MAX_THREADS_PER_USER}個）に達しています。他の交換日記を削除してから作成してください。"
        return
      end

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
    # 公開→非公開に戻そうとする場合、条件チェック
    if (@thread.free? || @thread.paid?) && !@thread.can_be_privatized?
      redirect_to thread_path(@thread.slug), alert: "強制公開条件（5投稿以上、または30日経過）を満たしているため、非公開にできません"
      return
    end

    @thread.toggle_published!
    state = @thread.draft? ? "非公開" : "公開"
    redirect_to thread_path(@thread.slug), notice: "交換日記を#{state}にしました"
  rescue ActiveRecord::RecordInvalid
    redirect_to thread_path(@thread.slug), alert: "公開状態の変更に失敗しました"
  end

  def export
    data = @thread.to_export_json
    filename = "#{@thread.slug}_export_#{Time.current.strftime('%Y%m%d%H%M%S')}.json"

    send_data data.to_json,
              filename: filename,
              type: "application/json",
              disposition: "attachment"
  end

  def export_with_images
    Rails.logger.info "Export with images started for thread #{@thread.slug} by user #{current_user.id}"
    start_time = Time.current

    zip_data = @thread.export_with_images_zip
    filename = "#{@thread.slug}_export_with_images_#{Time.current.strftime('%Y%m%d%H%M%S')}.zip"

    duration = Time.current - start_time
    Rails.logger.info "Export with images completed for thread #{@thread.slug}: #{zip_data.bytesize} bytes in #{duration.round(2)}s"

    send_data zip_data,
              filename: filename,
              type: "application/zip",
              disposition: "attachment"
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
    # status の変更は toggle_published 経由のみ許可（編集フォームからは変更不可）
    params.require(:thread).permit(:title, :slug, :description, :turn_based, :thumbnail, :show_in_list)
  end
end
