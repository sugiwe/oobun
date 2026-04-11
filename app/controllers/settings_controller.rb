class SettingsController < ApplicationController
  before_action :require_login

  # 投稿表示モード（Markdown/Plain）の設定を更新
  def update_post_view
    # enumの有効な値かチェック（markdown/plain のみ許可）
    unless User.preferred_post_views.key?(params[:preferred_post_view])
      head :unprocessable_entity
      return
    end

    if current_user.update(preferred_post_view: params[:preferred_post_view])
      head :ok
    else
      head :unprocessable_entity
    end
  end
end
