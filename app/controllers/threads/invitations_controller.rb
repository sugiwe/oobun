class Threads::InvitationsController < Threads::ApplicationController
  skip_before_action :require_login, only: [ :show ]
  skip_before_action :set_thread
  before_action :require_membership, only: [ :create ]
  before_action :set_thread_for_create, only: [ :create ]
  before_action :set_invitation, only: [ :show, :accept ]

  # POST /:thread_slug/invitation
  # スレッドメンバーが招待URLを発行する
  def create
    invitation = @thread.invitations.create!(invited_by: current_user)
    url = invitation_url(invitation.token)
    render json: { url: url }
  end

  # GET /invite/:token
  # 招待を受け取った人が承認画面を見る
  def show
    if @invitation.accepted?
      redirect_to thread_path(@invitation.thread.slug), notice: "この招待はすでに使用済みです"
    elsif @invitation.expired?
      redirect_to root_path, alert: "この招待URLは有効期限切れです"
    end
  end

  # POST /invite/:token
  # 招待を承認してメンバーになる
  def accept
    if @invitation.accepted?
      redirect_to thread_path(@invitation.thread.slug), notice: "この招待はすでに使用済みです"
      return
    end

    if @invitation.expired?
      redirect_to root_path, alert: "この招待URLは有効期限切れです"
      return
    end

    if @invitation.thread.memberships.exists?(user: current_user)
      redirect_to thread_path(@invitation.thread.slug), notice: "すでにこのスレッドのメンバーです"
      return
    end

    if @invitation.accept!(current_user)
      redirect_to thread_path(@invitation.thread.slug), notice: "スレッドに参加しました！"
    else
      redirect_to invitation_path(@invitation.token), alert: "参加に失敗しました"
    end
  end

  private

  def set_thread_for_create
    @thread = CorrespondenceThread.find_by!(slug: params[:thread_slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "スレッドが見つかりません"
  end

  def set_invitation
    @invitation = Invitation.includes(:thread).find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "招待URLが見つかりません"
  end
end
