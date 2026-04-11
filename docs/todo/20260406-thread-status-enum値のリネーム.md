# Thread status enum値のリネーム

**作成日**: 2026年4月6日
**優先度**: 中
**ステータス**: 未着手

## 背景

現在、`CorrespondenceThread`の`status` enumは以下の値を持っている：
- `draft`: 下書き（非公開）
- `free`: 無料公開
- `paid`: 有料公開（Phase 3で実装予定）

この命名だと「公開」の意味が不明確で分かりにくい。`free`と`paid`だけでは公開状態を表していることが伝わりづらい。

## 提案される変更

より明確な命名に変更する：
- `draft` → `draft`（そのまま）
- `free` → `published`（無料公開 → 公開）
- `paid` → `paid_published`（有料公開）

こうすることで：
- `draft?`の反対が`published?`になり直感的
- `published?`メソッドが自動生成される（enumの恩恵）
- 有料版も`paid_published?`で明確に「公開済み」であることが分かる

## 影響範囲

以下のファイルで`free?`、`paid?`、`draft?`が使用されている：
- `app/models/correspondence_thread.rb`
- `app/models/post.rb`
- `app/controllers/threads_controller.rb`
- `app/controllers/threads/posts_controller.rb`
- `app/views/threads/show.html.slim`
- `app/views/threads/_thread.html.slim`
- `app/views/threads/posts/show.html.slim`
- `app/views/threads/posts/edit.html.slim`
- `app/views/posts/_post_card.html.slim`
- `app/views/threads/show.rss.builder`
- `app/javascript/controllers/draft_autosave_controller.js`
- `spec/factories/correspondence_threads.rb`
- `spec/factories/posts.rb`
- `spec/models/user_spec.rb`
- `spec/services/notification_service_spec.rb`
- `db/seeds/sample_threads.rb`

（マイグレーションファイルやアーカイブドキュメントは除く）

## 実装手順

1. **マイグレーション作成**
   ```ruby
   class RenameThreadStatusValues < ActiveRecord::Migration[8.1]
     def up
       # free → published
       execute "UPDATE threads SET status = 'published' WHERE status = 'free'"
       # paid → paid_published (現時点では存在しないはずだが念のため)
       execute "UPDATE threads SET status = 'paid_published' WHERE status = 'paid'"
     end

     def down
       execute "UPDATE threads SET status = 'free' WHERE status = 'published'"
       execute "UPDATE threads SET status = 'paid' WHERE status = 'paid_published'"
     end
   end
   ```

2. **モデルのenum定義を更新**
   ```ruby
   enum :status, {
     draft: "draft",
     published: "published",      # 旧 free
     paid_published: "paid_published"  # 旧 paid
   }
   ```

3. **コード内の参照を一括置換**
   - `.free?` → `.published?`
   - `.paid?` → `.paid_published?`
   - `free!` → `published!`
   - `paid!` → `paid_published!`

4. **テストの更新**
   - Factoryの`status: :free` → `status: :published`
   - テストコード内の`free?` → `published?`

5. **動作確認**
   - 既存の公開スレッドが正常に表示されるか
   - 下書き/公開の切り替えが正常に動作するか
   - RSSフィードが正常に配信されるか
   - テストが全てパスするか

## 注意点

- データマイグレーションを含むため、本番環境への適用時は慎重に
- ダウンマイグレーションも用意しておく（ロールバック可能に）
- 影響範囲が広いため、一括置換後に十分なテストを実施する

## 関連issue

現在のブランチ（`feature/remove-login-restrictions`）で管理画面のユーザー詳細ページに`published?`メソッドが必要になり、この問題が発覚した。
