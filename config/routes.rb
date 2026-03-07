Rails.application.routes.draw do
  # ヘルスチェック
  get "up" => "rails/health#show", as: :rails_health_check

  # 認証
  get  "/login",  to: "sessions#new",     as: :login
  post "/session", to: "sessions#create",  as: :session
  delete "/session", to: "sessions#destroy", as: :logout

  # 開発環境専用：簡易ログイン
  if Rails.env.development?
    post "/dev_login/:username", to: "sessions#dev_login", as: :dev_login
  end

  # username 設定（新規ユーザーの Google ログイン後）
  get  "/username/new", to: "usernames#new",    as: :new_username
  post "/username",     to: "usernames#create", as: :username

  # 法務・サポートページ
  get "/about",   to: "pages#about",   as: :about
  get "/terms",   to: "pages#terms",   as: :terms
  get "/privacy", to: "pages#privacy", as: :privacy
  get "/contact", to: "pages#contact", as: :contact

  # ユーザーページ（最優先でマッチさせる）
  get  "/@:username",      to: "users#show",   as: :user
  get  "/@:username/edit", to: "users#edit",   as: :edit_user
  patch "/@:username",     to: "users#update"

  # トップページ（パーソナライズドフィード）
  root "threads#index"

  # 全スレッド一覧（ブラウズページ）
  get "/threads", to: "threads#browse", as: :browse_threads

  # 招待URL（トークンベース、スレッドURLとは独立）
  get  "/invite/:token", to: "threads/invitations#show",  as: :invitation
  post "/invite/:token", to: "threads/invitations#accept", as: :accept_invitation

  # Thread リソース（path: '' でプレフィックスなし）
  resources :threads, path: "", param: :slug, except: [ :index ] do
    # 招待発行（POST /:slug/invitation）
    resource :invitation, only: [ :create ], controller: "threads/invitations"
    # 公開/非公開切り替え & エクスポート
    member do
      patch :toggle_published
      get :export
      get :export_with_images
    end
    # ネストされたリソース
    resources :posts, except: [ :index ], controller: "threads/posts" do
      member do
        post :publish  # 下書きを公開
      end
    end
    resource :skip,         only: [ :create ], controller: "threads/skips"
    resource :subscription, only: [ :create, :destroy ], controller: "threads/subscriptions"
  end
end
