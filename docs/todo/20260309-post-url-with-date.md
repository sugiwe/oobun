# 投稿URLの日付ベース化

作成日: 2026-03-09

## 背景

現状の投稿URLは数値ID（`/thread-slug/123`）を使用しているが、以下の課題がある：

- スキップ・削除で番号が歯抜けになる
- 投稿数が推測できてしまう
- システム内部の情報が露出

## 決定事項

**日付ベースのURL** (`/thread-slug/2026-03-08`) を採用する。

### 重要な設計判断: 公開時に日付URLを決定

- **下書き中**: `slug` は `null`（数値IDでアクセス）
- **公開時**: その時点の日付で `slug` を生成
- **公開後**: `slug` は不変（URLが変わらない）

これにより、下書きを数日間編集してから公開しても、**公開日がURLに反映される**。

## 理由

1. **URLの不変性（最重要）**
   - 外部リンク・ブックマークが壊れない
   - Googleインデックスが安定
   - SNSシェアが安全

2. **意味のある情報**
   - 「2026年3月8日の投稿」が直感的
   - SEO的に有利（日付キーワード）

3. **coconikkiの特性に合う**
   - 基本的に1日1往復ペース
   - `-1`, `-2` の連番が必要なケースは少ない
   - 同日投稿があっても「同じ日の2通目」として意味がある

4. **シンプルな実装**
   - 削除時に番号を振り直す必要がない
   - 他の投稿に影響しない

## URL形式

```
/thread-slug/2026-03-08       # その日の1通目
/thread-slug/2026-03-08-2     # その日の2通目（同日投稿がある場合）
/thread-slug/2026-03-08-3     # その日の3通目（非常にまれ）
```

## 実装方針

### 1. データベース変更

```ruby
# マイグレーション
class AddSlugToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :slug, :string
    add_index :posts, [:thread_id, :slug], unique: true
  end
end
```

### 2. Postモデルの変更

```ruby
# app/models/post.rb
class Post < ApplicationRecord
  # 公開時に slug を生成
  before_save :generate_slug_if_published

  # slug は公開済み投稿のみ必須
  validates :slug, presence: true, if: :published?
  validates :slug, uniqueness: { scope: :thread_id }, allow_nil: true

  # to_param をオーバーライド（公開済みなら slug、下書きなら id）
  def to_param
    published? && slug.present? ? slug : id.to_s
  end

  private

  def generate_slug_if_published
    # 既に slug がある場合はスキップ（不変性を保証）
    return if slug.present?

    # 公開済みの場合のみ slug を生成
    return unless published?

    # 現在時刻（公開時点）で日付を取得（JST）
    base = Time.current.in_time_zone('Asia/Tokyo').strftime('%Y-%m-%d')

    # 同日投稿の数を取得（スレッド内で）
    existing_count = thread.posts
                           .where("slug LIKE ?", "#{base}%")
                           .where.not(id: id)
                           .count

    self.slug = existing_count.zero? ? base : "#{base}-#{existing_count + 1}"
  end
end
```

### 3. ルーティングの変更

```ruby
# config/routes.rb
resources :threads, param: :slug, only: [:index, :show, :create, :update, :destroy] do
  # param: :slug を指定することで、Rails が to_param を使用する
  resources :posts, param: :slug, except: [:index], controller: 'threads/posts'

  # その他のルート...
end
```

### 4. コントローラーの変更

```ruby
# app/controllers/threads/posts_controller.rb
class Threads::PostsController < ApplicationController
  before_action :set_thread
  before_action :set_post, only: [:show, :edit, :update, :destroy]

  private

  def set_post
    # params[:slug] が数値IDか日付スラグかを判定
    @post = if params[:slug] =~ /^\d+$/
      # 数値IDの場合（下書き or 旧URL）
      post = @thread.posts.find(params[:slug])

      # 公開済みで slug がある場合は301リダイレクト
      if post.published? && post.slug.present?
        redirect_to thread_post_path(@thread.slug, post.slug), status: :moved_permanently
        return
      end

      post
    else
      # 日付スラグの場合
      @thread.posts.find_by!(slug: params[:slug])
    end
  end
end
```

### 5. ビューの変更

**変更不要！**

全ての `thread_post_path(@thread.slug, @post)` は変更せずにそのまま使える。
Rails が自動的に `@post.to_param` を呼び出すため、モデルで定義した `to_param` が使用される。

### 6. 既存データの移行

```ruby
# lib/tasks/posts.rake
namespace :posts do
  desc "Generate slugs for existing published posts"
  task generate_slugs: :environment do
    # 公開済み投稿のみ slug を生成
    Post.published.where(slug: nil).find_each do |post|
      # published_at または created_at の日付を使用
      base_date = (post.published_at || post.created_at).in_time_zone('Asia/Tokyo')
      base = base_date.strftime('%Y-%m-%d')

      # 同日投稿の数を取得
      existing_count = post.thread.posts
                           .where("slug LIKE ?", "#{base}%")
                           .where.not(id: post.id)
                           .count

      post.slug = existing_count.zero? ? base : "#{base}-#{existing_count + 1}"
      post.save!(validate: false)

      puts "Post ##{post.id}: #{post.slug}"
    end

    # 下書きは slug を生成しない（null のまま）
    draft_count = Post.draft.count
    puts "\n下書き #{draft_count} 件は slug なしのまま（公開時に生成されます）"
  end
end
```

## 実装の流れ

1. ブランチを作成: `git checkout -b feature/post-url-with-date`
2. マイグレーションを作成・実行
3. Postモデルに `slug` 生成ロジックを追加
4. 既存データに `slug` を付与（rake タスク実行）
5. ルーティングを変更
6. コントローラーを変更（`find` → `find_by!` with slug）
7. `to_param` メソッドを追加
8. テスト実行
9. 本番デプロイ

## マイグレーション手順（本番）

1. マイグレーションを実行（`slug` カラム追加）
2. Rake タスクで既存データに `slug` を付与
3. アプリケーションを再起動（新コードをデプロイ）
4. 旧URL（数値ID）は301リダイレクトで新URLへ誘導

## 注意事項

### URLの不変性
- **公開後はURLが変わらない**: slug は公開時に一度だけ生成され、以降変更されない
- **下書き中のURL**: 数値ID（`/thread-slug/123`）を使用
- **公開時**: 日付スラグ（`/thread-slug/2026-03-08`）に切り替わる
- **旧URLからのリダイレクト**: 数値IDでアクセスされた場合、公開済み投稿なら日付スラグへ301リダイレクト

### 下書きから公開への流れ
1. **下書き作成**: `slug` は `null`、URL は `/thread-slug/123`（数値ID）
2. **下書き編集**: 数日間編集しても `slug` は `null` のまま
3. **公開**: その時点の日付で `slug` を生成（例: `2026-03-08`）
4. **公開後**: URL は `/thread-slug/2026-03-08` に固定（不変）

### 同日投稿の連番
- 削除されても連番は変わらない（例: `-2` を削除しても `-3` は `-3` のまま）
- 連番は「何番目の投稿か」ではなく「この日付で何番目に生成されたか」を示す

### タイムゾーン
- JST（Asia/Tokyo）で日付を生成
- `Time.current.in_time_zone('Asia/Tokyo')` を使用
- データベースの `created_at` は UTC で保存されているため、変換が必要

## テストケース

### 下書き関連
- [ ] 下書き作成時は `slug` が `null`
- [ ] 下書き編集中も `slug` は `null` のまま
- [ ] 下書きのURL は数値ID（`/thread-slug/123`）

### 公開関連
- [ ] 公開時に `slug` が生成される（その時点の日付）
- [ ] 同日に複数投稿がある場合、`-2`, `-3` が付与される
- [ ] 公開後に編集しても `slug` は変わらない

### リダイレクト
- [ ] 数値IDでアクセスした公開済み投稿は、日付スラグへ301リダイレクト
- [ ] 数値IDでアクセスした下書きは、そのまま表示（リダイレクトしない）

### その他
- [ ] 削除しても他の投稿のスラグは変わらない
- [ ] スラグが重複しない（スレッド内で一意）
- [ ] タイムゾーンが正しい（JSTで日付が生成される）
- [ ] 下書きを数日後に公開した場合、公開日がURLになる（下書き作成日ではない）

## 参考

- 既存の類似実装: スレッドのslug（`CorrespondenceThread` モデル）
- Friendly ID gem: 今回は不要（シンプルな実装で十分）

## 完了条件

- [ ] マイグレーション実行
- [ ] 既存データに slug 付与
- [ ] ルーティング変更
- [ ] コントローラー変更
- [ ] テスト実行（全て通過）
- [ ] 本番デプロイ
- [ ] 旧URLから新URLへのリダイレクト確認
