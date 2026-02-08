# 設計ドキュメント

## モデル設計

### User

認証主体。Google OAuth ログインを想定。

- id
- username (unique, URL用: `@alice` 形式)
- display_name (表示名)
- email
- avatar_url
- created_at / updated_at

**制約**

- username: 英数字、ハイフン、アンダースコアのみ、3〜20文字
- username: ユニーク制約

**関連**

- has_many :memberships
- has_many :threads, through: :memberships
- has_many :posts
- has_many :subscriptions
- has_many :subscribed_threads, through: :subscriptions, source: :thread

---

### Thread

文通の「箱」。やりとりの単位。

- id
- title
- slug (unique, URL用: `alice-and-bob-daily-letters` 形式)
- description
- visibility (enum: public/url_only/followers_only/paid, default: public)
- turn_based (boolean, default: true)
- last_post_user_id (交代制判定用)
- last_posted_at (最終投稿日時、ソート用)
- created_at / updated_at

**制約**

- slug: 英数字とハイフンのみ、3〜50文字、ユニーク制約
- slug: 作成時に手動入力(必須)、後から編集可能
- slug: 予約語チェック(admin, api, about, help, settings, terms, privacy, posts, users等)

**関連**

- has_many :memberships
- has_many :users, through: :memberships
- has_many :posts
- has_many :subscriptions
- has_many :subscribers, through: :subscriptions, source: :user

---

### Membership

「このスレッドを書いている当事者」を表す中間モデル。

※ 将来の「購読者」「課金ユーザー」(Subscription)とは明確に区別する。

- id
- user_id
- thread_id
- position (integer, 交代順序: 1, 2, 3...)
- role (enum: writer, default: writer)
- created_at / updated_at

**制約**

- position: Thread 内でユニーク(同じスレッド内で重複不可)
- position: 1 から連番で設定

**補足**

- 初期実装では role は writer のみ(全員が投稿可能)
- 将来的に owner/moderator などの権限を追加可能
- position により交代順序を管理(2人でも3人以上でも統一ルール)
- メンバー削除は基本的に想定しない(「文通」の特性上、途中退出は別スレッド作成を推奨)
- 新メンバー追加時は現在の最大 position + 1 を割り当てる

---

### Post

Thread 内の1つ1つの投稿（手紙）。

- id
- thread_id
- user_id
- body (text)
- published_at (公開日時、下書き機能拡張用)
- created_at / updated_at

**制約**

- body: 最小10文字、最大10,000文字(将来的に有料プランで緩和可能)

**補足**

- 投稿は個別ページを持つ: `/:slug/:post_id`
- Thread 詳細ページでは抜粋表示(300文字程度)、「続きを読む」で詳細へ
- Post 詳細ページには前後のナビゲーション(`prev`, `next` メソッド)
- 将来的に like / reaction を付与可能
- 初期実装では編集・削除機能なし

**関連**

- belongs_to :thread
- belongs_to :user

---

### Subscription

第三者ユーザーによる「文通の購読」を表すモデル。

- id
- user_id
- thread_id
- created_at / updated_at

**補足**

- 「購読する」という表現で UI に表示
- 将来的に有料購読(paid tier)への拡張を想定
- Membership(書き手)とは明確に区別される

---

### Skip

スキップ履歴を記録するモデル。初期実装から含める。

- id
- user_id
- thread_id
- created_at / updated_at

**補足**

- 自分のターンの時にスキップ可能
- スキップすると次の position のユーザーにターンが移る
- UI: 投稿フォームに「今回はパス」ボタンを配置
- 履歴を残すことで、将来的に「誰が何回スキップしたか」を可視化可能

**関連**

- belongs_to :user
- belongs_to :thread

---

## ルーティング設計

RESTful な設計を採用。可能な限りリソースベースで表現する。
**Thread URL から `/threads` プレフィックスを省略**してシンプルに。

### 基本URL構造

```
/                          → トップページ(Thread 一覧)
/@username                 → ユーザーページ
/:slug                     → Thread 詳細
/:slug/:post_id            → Post 詳細
/:slug/posts/new           → 新規投稿フォーム
```

### Thread リソース(path: '' でプレフィックス省略)

- GET    `/` (一覧: ThreadsController#index, root)
- GET    `/new` (新規作成フォーム: ThreadsController#new)
- POST   `/` (作成: ThreadsController#create)
- GET    `/:slug` (詳細: ThreadsController#show)
- GET    `/:slug.rss` (RSS フィード: ThreadsController#show format: rss)
- GET    `/:slug/edit` (編集フォーム: ThreadsController#edit, 将来)
- PATCH  `/:slug` (更新: ThreadsController#update, 将来)

### Post リソース(threads にネスト)

- GET    `/:thread_slug/posts/new` (投稿フォーム: PostsController#new)
- POST   `/:thread_slug/posts` (投稿: PostsController#create)
- GET    `/:thread_slug/:id` (詳細: PostsController#show)

### Skip リソース(threads にネスト、単数形リソース)

- POST   `/:thread_slug/skip` (ターンスキップ: SkipsController#create)

### Subscription リソース(threads にネスト、単数形リソース)

- POST   `/:thread_slug/subscription` (購読: SubscriptionsController#create)
- DELETE `/:thread_slug/subscription` (購読解除: SubscriptionsController#destroy)

### User リソース

- GET `/@:username` (ユーザーページ: UsersController#show)
- GET `/settings` (設定: UsersController#edit, 将来)

### routes.rb イメージ

```ruby
Rails.application.routes.draw do
  # ユーザーページ(最優先でマッチ)
  get '/@:username', to: 'users#show', as: :user

  # トップページ
  root 'threads#index'

  # Thread リソース(path: '' でプレフィックスなし)
  resources :threads, path: '', param: :slug, except: [:index] do
    # RSS フィード
    member do
      get '', to: 'threads#show', defaults: { format: 'rss' }, constraints: { format: 'rss' }
    end

    # ネストされたリソース
    resources :posts, only: [:new, :create, :show]
    resource :skip, only: [:create]           # 単数形リソース(ID不要)
    resource :subscription, only: [:create, :destroy]  # 単数形リソース(ID不要)
  end
end
```

**補足**:

- `path: ''` で `/threads` プレフィックスを省略
- `except: [:index]` で重複する `/threads` を無効化(root で代用)
- `/@:username` を先に定義して優先マッチ
- `resource`(単数形)で現在のユーザーの Subscription を暗黙的に扱う
- `param: :slug` で Thread のパラメータを `:id` から `:slug` に変更

### 予約語管理

以下の slug は使用不可(ルーティング衝突を防ぐ):

```ruby
RESERVED_SLUGS = %w[
  admin api about help settings terms privacy posts users new edit
  login logout auth oauth callback feeds rss assets rails
].freeze
```

---

## 交代制ロジック

- Thread.turn_based = true の場合のみ有効
- Membership の `position` により交代順序を管理
- 現在のターン = `last_post_user_id` のユーザーの次の position の人
- 投稿成功時に `last_post_user_id` と `last_posted_at` を更新

**ロジック詳細**

- Thread 作成直後: `last_post_user_id` は `nil`（まだ誰も投稿していない状態）
- `last_post_user_id` が `nil` の場合: position 1 のユーザーのターン
- 2人の場合: position 1 → 2 → 1 → 2...
- 3人以上の場合: position 1 → 2 → 3 → 1 → 2...
- 最大 position の次は position 1 に戻る(循環)

※ turn_based = false の場合は自由投稿(position 関係なし)

**スキップ機能（初期実装に含める）**

- 自分のターンの時にスキップ可能
- Skip リソースとして実装: `POST /:thread_slug/skip`
- スキップすると次の position のユーザーにターンが移る
- UI: 投稿フォームに「今回はパス」ボタンを配置
- 将来的にスキップ履歴を記録する拡張も可能
