class Threads::SkipsController < Threads::ApplicationController
  before_action :require_membership
  before_action :require_my_turn

  def create
    ActiveRecord::Base.transaction do
      # 下書きがあれば削除
      draft = @thread.draft_for(current_user)
      draft.destroy! if draft

      Skip.create!(user: current_user, thread: @thread)
    end
    redirect_to thread_path(@thread.slug), notice: "スキップしました"
  end
end
