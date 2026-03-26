class Threads::InvitationsController < Threads::ApplicationController
  skip_before_action :require_login, only: [ :show ]
  skip_before_action :set_thread, only: [ :show, :accept ]
  before_action :require_admin, only: [ :create, :destroy ]
  before_action :set_invitation, only: [ :show, :accept, :destroy ]
  before_action :check_invitation_status, only: [ :show, :accept ]

  # POST /:thread_slug/invitation
  # 交換日記メンバーが招待URLを発行する
  def create
    invitation = @thread.invitations.create!(
      invited_by: current_user,
      invitation_type: invitation_params[:invitation_type] || "single_use",
      expiry_type: invitation_params[:expiry_type] || "seven_days"
    )
    url = invitation_url(invitation.token)

    respond_to do |format|
      format.json { render json: { url: url } }
      format.html { redirect_to edit_thread_path(@thread.slug), notice: "招待リンクを作成しました" }
    end
  end

  # GET /invite/:token
  # 招待を受け取った人が承認画面を見る
  def show
    # 招待トークンをセッションに保存（ログイン許可に使用）
    session[:invitation_token] = @invitation.token
    # 未ログイン時も招待画面を表示（show.html.slimで分岐）
  end

  # DELETE /:thread_slug/invitations/:token
  # 招待リンクを削除
  def destroy
    @invitation.destroy!
    redirect_to edit_thread_path(@invitation.thread.slug), notice: "招待リンクを削除しました"
  end

  # POST /invite/:token
  # 招待を承認してメンバーになる
  def accept
    if @invitation.thread.memberships.exists?(user: current_user)
      redirect_to thread_path(@invitation.thread.slug), notice: "すでにこの交換日記のメンバーです"
      return
    end

    # 競合状態を防ぐためにユーザーレコードをロック
    current_user.with_lock do
      unless current_user.can_join_thread?
        redirect_to root_path, alert: "参加できる交換日記の上限（#{User::MAX_THREADS_PER_USER}個）に達しています。他の交換日記から退出してから参加してください。"
        return
      end

      if @invitation.accept!(current_user)
        # 招待トークンをセッションから削除
        session.delete(:invitation_token)
        redirect_to thread_path(@invitation.thread.slug), notice: "交換日記に参加しました！"
      else
        redirect_to invitation_path(@invitation.token), alert: "参加に失敗しました"
      end
    end
  end

  private

  def check_invitation_status
    unless @invitation.usable?
      if @invitation.accepted?
        redirect_to thread_path(@invitation.thread.slug), notice: "この招待はすでに使用済みです"
      elsif @invitation.expired?
        redirect_to root_path, alert: "この招待URLは有効期限切れです"
      end
    end
  end

  def set_invitation
    @invitation = Invitation.includes(:thread).find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "招待URLが見つかりません"
  end

  def invitation_params
    params.permit(:invitation_type, :expiry_type)
  end
end
