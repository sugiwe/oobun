class SubscriptionsController < ApplicationController
  before_action :set_thread

  def create
    @thread.subscriptions.find_or_create_by!(user: current_user)
    redirect_to thread_path(@thread.slug), notice: "購読しました"
  end

  def destroy
    subscription = @thread.subscriptions.find_by(user: current_user)
    subscription&.destroy
    redirect_to thread_path(@thread.slug), notice: "購読を解除しました"
  end

  private

  def set_thread
    @thread = CorrespondenceThread.find_by!(slug: params[:thread_slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "スレッドが見つかりません"
  end
end
