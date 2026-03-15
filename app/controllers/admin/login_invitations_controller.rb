class Admin::LoginInvitationsController < Admin::ApplicationController
  # GET /admin/login_invitations
  def index
    @login_invitations = LoginInvitation.includes(:created_by, :allowed_users).order(created_at: :desc)
  end

  # GET /admin/login_invitations/new
  def new
    @login_invitation = LoginInvitation.new
  end

  # POST /admin/login_invitations
  def create
    @login_invitation = LoginInvitation.new(login_invitation_params)
    @login_invitation.created_by = current_user

    if @login_invitation.save
      redirect_to admin_login_invitation_path(@login_invitation), status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /admin/login_invitations/:id
  def show
    @login_invitation = LoginInvitation.includes(:allowed_users).find(params[:id])
    @url = login_invitation_url(@login_invitation.token)
  end

  private

  def login_invitation_params
    params.require(:login_invitation).permit(:note, :unlimited)
  end
end
