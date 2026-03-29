# System test helpers
module SystemHelpers
  # ユーザーとしてログインする（セッションベース）
  # ApplicationControllerのcurrent_userとlogged_in?をモックする
  def login_as(user)
    # ApplicationControllerのメソッドをモック
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:require_login).and_return(true)
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system
end
