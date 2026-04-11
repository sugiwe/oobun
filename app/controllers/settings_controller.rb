class SettingsController < ApplicationController
  before_action :require_login

  # 投稿表示モード（Markdown/Plain）の設定を更新
  def update_post_view
    if current_user.update(preferred_post_view: params[:preferred_post_view])
      head :ok
    else
      head :unprocessable_entity
    end
  end
end
