class AnnotationsController < ApplicationController
  def index
    @annotations = current_user.annotations
                                .includes(post: { thread: :users })
                                .order(created_at: :desc)
                                .page(params[:page])
                                .per(20)
  end
end
