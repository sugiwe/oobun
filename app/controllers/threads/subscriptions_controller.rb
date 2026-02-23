class Threads::SubscriptionsController < Threads::ApplicationController
  def create
    @thread.subscriptions.find_or_create_by!(user: current_user)
    redirect_to thread_path(@thread.slug), notice: "購読しました"
  end

  def destroy
    subscription = @thread.subscriptions.find_by(user: current_user)
    subscription&.destroy
    redirect_to thread_path(@thread.slug), notice: "購読を解除しました"
  end
end
