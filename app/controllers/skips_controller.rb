class SkipsController < ApplicationController
  before_action :set_thread
  before_action :require_membership
  before_action :require_my_turn

  def create
    Skip.create!(user: current_user, thread: @thread)
    redirect_to thread_path(@thread.slug), notice: "スキップしました"
  end

  private

  def set_thread
    @thread = CorrespondenceThread.find_by!(slug: params[:thread_slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "スレッドが見つかりません"
  end

  def require_membership
    unless @thread.memberships.exists?(user: current_user)
      redirect_to thread_path(@thread.slug), alert: "このスレッドのメンバーではありません"
    end
  end

  def require_my_turn
    unless @thread.my_turn?(current_user)
      redirect_to thread_path(@thread.slug), alert: "今はあなたのターンではありません"
    end
  end
end
