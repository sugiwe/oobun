class Threads::SkipsController < Threads::ApplicationController
  before_action :require_membership
  before_action :require_my_turn

  def create
    Skip.create!(user: current_user, thread: @thread)
    redirect_to thread_path(@thread.slug), notice: "スキップしました"
  end
end
