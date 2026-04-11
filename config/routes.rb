Rails.application.routes.draw do
  # ヘルスチェック
  get "up" => "rails/health#show", as: :rails_health_check

  # 認証
  get  "/login",  to: "sessions#new",     as: :login
  post "/session", to: "sessions#create",  as: :session
  delete "/session", to: "sessions#destroy", as: :logout

  # 開発環境専用：簡易ログイン・メールプレビュー
  if Rails.env.development?
    post "/dev_login/:username", to: "sessions#dev_login", as: :dev_login
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  # username 設定（新規ユーザーの Google ログイン後）
  get  "/username/new", to: "usernames#new",    as: :new_username
  post "/username",     to: "usernames#create", as: :username

  # ウェルカムページ
  get "/welcome", to: "welcome#show", as: :welcome

  # 法務・サポートページ
  get "/about",   to: "pages#about",   as: :about
  get "/terms",   to: "pages#terms",   as: :terms
  get "/privacy", to: "pages#privacy", as: :privacy
  get "/contact", to: "pages#contact", as: :contact
  get "/markdown-guide", to: "pages#markdown_guide", as: :markdown_guide

  # 通知
  resources :notifications, only: [ :index ] do
    member do
      patch :mark_as_read
    end
  end

  # 設定
  namespace :settings do
    resource :notifications, only: [ :show, :update ] do
      post :send_test
    end
  end

  # 投稿表示モード設定（namespace外で定義）
  patch "/settings/post_view", to: "settings#update_post_view", as: :settings_post_view

  # ユーザーページ（最優先でマッチさせる）
  get    "/@:username",        to: "users#show",   as: :user
  get    "/@:username/edit",   to: "users#edit",   as: :edit_user
  patch  "/@:username",        to: "users#update"
  get    "/@:username/delete", to: "users#delete_confirmation", as: :delete_confirmation_user
  delete "/@:username",        to: "users#destroy"

  # トップページ（パーソナライズドフィード）
  root "threads#index"

  # 全スレッド一覧（ブラウズページ）
  get "/threads", to: "threads#browse", as: :browse_threads

  # フォロー中交換日記の投稿一覧（ログイン必須）
  get "/subscription_posts", to: "threads#subscription_posts", as: :subscription_posts

  # 管理画面（管理者のみ）
  namespace :admin do
    root to: "dashboard#index"
    resources :users, only: [ :index, :show ]
  end

  # マークダウンプレビュー
  post "/preview_markdown", to: "markdown_previews#create", as: :preview_markdown

  # OGP取得
  post "/fetch_ogp", to: "ogp_fetches#create", as: :fetch_ogp

  # 交換日記招待URL（トークンベース、スレッドURLとは独立）
  get  "/invite/:token", to: "threads/invitations#show",  as: :invitation
  post "/invite/:token", to: "threads/invitations#accept", as: :accept_invitation

  # Thread リソース（path: '' でプレフィックスなし）
  resources :threads, path: "", param: :slug, except: [ :index ] do
    # 招待発行と削除
    resource :invitation, only: [ :create ], controller: "threads/invitations"
    delete "invitations/:token", to: "threads/invitations#destroy", as: :delete_invitation
    # 公開/非公開切り替え & エクスポート & 削除確認
    member do
      patch :toggle_published
      get :export
      get :export_with_images
      get :delete, to: "threads#delete_confirmation", as: :delete_confirmation
    end
    # ネストされたリソース
    resources :posts, except: [ :index ], controller: "threads/posts" do
      member do
        post :publish  # 下書きを公開
      end
    end
    resource :skip,         only: [ :create ], controller: "threads/skips"
    resource :subscription, only: [ :create, :destroy ], controller: "threads/subscriptions"
    resource :membership,   only: [ :destroy ], controller: "threads/memberships"
    delete "memberships/:user_id", to: "threads/memberships#remove_member", as: :remove_membership
    patch "memberships/:user_id/promote", to: "threads/memberships#promote_to_admin", as: :promote_membership
    patch "memberships/:user_id/demote", to: "threads/memberships#demote_to_member", as: :demote_membership
  end
end
