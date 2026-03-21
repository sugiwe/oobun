class WelcomeController < ApplicationController
  before_action :require_login

  def show
    # ウェルカムページを表示
  end
end
