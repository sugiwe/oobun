# Phase 1 完成へのTODO

作成日: 2026年2月18日

---

## 現在の実装状況

| タスク | 状態 | 備考 |
|---|---|---|
| User 認証(Google OAuth) | ✅ | 完了 |
| username 設定 | ✅ | 完了 |
| Thread CRUD | ✅ | index/show/new/create 完了 |
| Membership | ✅ | 招待URL機能で拡張済み |
| Post CRUD | ✅ | show/new/create 完了、タイトル追加済み |
| 交代制ロジック | ✅ | current_turn_user / my_turn? 実装済み |
| スキップ機能 | ❌ | モデルのみ作成済み |
| RSS フィード | ❌ | 未実装 |
| トップページ | ⚠️ | 一覧表示のみ、購読機能未実装 |
| Thread 詳細ページ | ⚠️ | 表示完成、購読ボタン・RSS未実装 |
| Post 詳細ページ | ⚠️ | 全文表示完成、前後ナビ未実装 |
| ユーザーページ | ❌ | 未実装（routes定義のみ） |

---

## 残タスク（Phase 1 完成）

### 1. UsersController とユーザーページ実装 (推定15分)

**概要**
- `/@username` でユーザーページを表示
- 参加中スレッド一覧を表示

**実装内容**
- [ ] `app/controllers/users_controller.rb` 作成
  - `show` アクション: username からユーザーを取得
  - 参加中スレッド（Membership経由）を取得
- [ ] `app/views/users/show.html.slim` 作成
  - ユーザー情報（display_name, username, avatar）
  - 参加中スレッド一覧（カード形式）

**エラー回避**
- 現在 routes で定義されているが実装がないためエラーになる

---

### 2. Subscription 機能（購読/購読解除） (推定30分)

**概要**
- Thread を購読/購読解除できる
- トップページで購読中スレッドを優先表示

**実装内容**
- [ ] `app/controllers/subscriptions_controller.rb` 作成
  - `create`: 購読
  - `destroy`: 購読解除
- [ ] Thread 詳細ページに購読ボタン追加
  - 購読済みなら「購読中」（destroy フォーム）
  - 未購読なら「購読する」（create フォーム）
- [ ] トップページ改善
  - ログインユーザーの場合: 購読中スレッドを上部に表示
  - 購読がない場合: 全公開スレッド一覧

---

### 3. Skip 機能（ターンスキップ） (推定20分)

**概要**
- 自分のターンの時に「今回はパス」でスキップ可能
- スキップすると次の position のユーザーにターンが移る

**実装内容**
- [ ] `app/controllers/skips_controller.rb` 作成
  - `create`: Skip レコード作成 + last_post_user_id 更新
- [ ] 投稿フォームに「今回はパス」ボタン追加
  - `app/views/posts/new.html.slim`
  - または Thread 詳細ページの投稿ボタンの隣に配置
- [ ] Skip モデルに `after_create` コールバック追加
  - Thread の `last_post_user_id` を次のユーザーに更新

**設計メモ**
- Skip は履歴として残す（将来の可視化用）
- スキップ後のターン計算は `CorrespondenceThread#current_turn_user` ロジックを活用

---

### 4. RSS フィード (推定20分)

**概要**
- `/:slug.rss` で個別スレッドの RSS を配信
- 最新10件の投稿を配信

**実装内容**
- [ ] ThreadsController の `show` に `respond_to` 追加
  ```ruby
  def show
    @posts = @thread.posts.includes(:user).reorder(created_at: :desc)
    @members = @thread.memberships.includes(:user).order(:position)

    respond_to do |format|
      format.html
      format.rss { render layout: false }
    end
  end
  ```
- [ ] `app/views/threads/show.rss.builder` 作成
  - RSS 2.0 形式で配信
  - 各投稿のタイトル・本文・リンクを含む
- [ ] Thread 詳細ページに RSS リンク追加
  - `= link_to "RSS", thread_path(@thread.slug, format: :rss)`

---

### 5. Post 詳細ページの前後ナビゲーション (推定15分)

**概要**
- Post 詳細ページに「← 前の投稿」「次の投稿 →」リンク

**実装内容**
- [ ] Post モデルに `prev` / `next` メソッド追加
  ```ruby
  def prev
    thread.posts.where("created_at < ?", created_at).order(created_at: :desc).first
  end

  def next
    thread.posts.where("created_at > ?", created_at).order(created_at: :asc).first
  end
  ```
- [ ] `app/views/posts/show.html.slim` に前後ナビ追加
  - 前の投稿があれば「← 前の投稿」リンク
  - 次の投稿があれば「次の投稿 →」リンク

---

## Phase 1 完成後の方向性

### Phase 1.5（UX 改善）
- 投稿時の文字数カウンター（Stimulus）
- Thread 編集機能のUI実装
- エラーハンドリング強化（404カスタマイズ等）

### Phase 2（コミュニティ機能）
- ページネーション改善（Pagy gem）
- 検索機能（Thread タイトル・本文）
- 購読中スレッド一覧の強化

### Phase 3（品質向上）
- OGP 対応（カスタム画像生成）
- 編集・削除機能の検討
- 下書き機能
- visibility の拡張（url_only, followers_only 等）

---

## 作業メモ

- [ ] UsersController 実装
- [ ] Subscription 機能実装
- [ ] Skip 機能実装
- [ ] RSS フィード実装
- [ ] Post 前後ナビ実装
- [ ] Phase 1 完成を docs/implementation.md に記録
- [ ] Phase 2 への移行判断
