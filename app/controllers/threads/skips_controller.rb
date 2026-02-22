class Threads::SkipsController < Threads::ApplicationController
  before_action :require_membership
  before_action :require_my_turn

  def create
    Skip.create!(user: current_user, thread: @thread)
    redirect_to thread_path(@thread.slug), notice: "スキップしました"
  end

  private

  def require_my_turn
    unless @thread.my_turn?(current_user)
      redirect_to thread_path(@thread.slug), alert: "今はあなたのターンではありません"
    end
  end
end
