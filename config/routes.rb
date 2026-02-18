Rails.application.routes.draw do
  # ヘルスチェック
  get "up" => "rails/health#show", as: :rails_health_check

  # 認証
  get  "/login",  to: "sessions#new",     as: :login
  post "/session", to: "sessions#create",  as: :session
  delete "/session", to: "sessions#destroy", as: :logout

  # username 設定（新規ユーザーの Google ログイン後）
  get  "/username/new", to: "usernames#new",    as: :new_username
  post "/username",     to: "usernames#create", as: :username

  # ユーザーページ（最優先でマッチさせる）
  get "/@:username", to: "users#show", as: :user

  # トップページ
  root "threads#index"

  # 招待URL（トークンベース、スレッドURLとは独立）
  get  "/invite/:token", to: "invitations#show",  as: :invitation
  post "/invite/:token", to: "invitations#accept", as: :accept_invitation

  # Thread リソース（path: '' でプレフィックスなし）
  resources :threads, path: "", param: :slug, except: [ :index ] do
    # 招待発行（POST /:slug/invitation）
    resource :invitation, only: [ :create ]
    # ネストされたリソース
    resources :posts, only: [ :new, :create, :show ]
    resource :skip,         only: [ :create ]
    resource :subscription, only: [ :create, :destroy ]
  end
end
