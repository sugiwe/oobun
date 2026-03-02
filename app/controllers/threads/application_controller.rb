class Threads::ApplicationController < ApplicationController
  before_action :set_thread

  private

  def set_thread
    @thread = CorrespondenceThread.find_by!(slug: params[:thread_slug] || params[:slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "交換日記が見つかりません"
  end

  def require_membership
    unless @thread.memberships.exists?(user: current_user)
      redirect_to thread_path(@thread.slug), alert: "この交換日記のメンバーではありません"
    end
  end

  def require_my_turn
    unless @thread.my_turn?(current_user)
      redirect_to thread_path(@thread.slug), alert: "今はあなたのターンではありません"
    end
  end
end
