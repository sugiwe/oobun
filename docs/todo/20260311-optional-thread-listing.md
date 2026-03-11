# 交換日記の一覧表示オプション機能

作成日: 2026-03-11

## 背景

現状、すべての公開スレッドがトップページに自動表示され、発見性が高い設計になっている。

一方で：
- 「しずかなインターネット」的な価値観との親和性を重視したい
- 書き手が望まない注目を避けられるようにしたい
- 電気通信事業法対応として、すべてのスレッドを「公開」状態に保つ必要がある

## 決定事項

**一覧表示のオプトイン方式** を導入する。

### 仕組み

- スレッド作成時・編集時に「この交換日記を一覧ページに表示する」チェックボックスを追加
- **デフォルト: オフ**（チェックなし）
- チェックを入れた場合のみ、トップページ（`/`）およびスレッド一覧ページ（`/threads`）に表示
- チェックを入れない場合でも、**スレッドは公開されている**（URLを知っていれば誰でもアクセス可能）

### 注意書き

チェックボックス付近に以下のような注意書きを表示：

```
💡 一覧に表示しない場合でも、この交換日記は公開されています。
   URLを知っている人は誰でも閲覧できます。非公開ではありませんのでご注意ください。
```

## 理由

### 1. **電気通信事業法対応（最重要）**
- すべてのスレッドが「公開」（URLアクセス可能）
- 「通信の秘密」に該当しない
- 届出不要な状態を確実に維持

### 2. **「しずかなインターネット」との親和性**
- 書き手が露出度を選択できる
- デフォルトでは一覧に出ない（しずかに書ける）
- 拡散したい人は一覧表示をオンにするか、SNSで共有

### 3. **coconikkiの本質**
- 「文通を公開する」という本質は変わらない
- URLを共有すれば、誰でも読める
- 強制的な露出ではなく、書き手の意思を尊重

### 4. **成長性の確保**
- 一覧表示を選んだスレッドは発見される
- 将来的なフィルター機能で発見性を向上
- オプトインでの公開により、質の高いコンテンツが集まる

## 実装方針

### 1. データベース変更

```ruby
# マイグレーション
class AddShowInListToCorrespondenceThreads < ActiveRecord::Migration[8.1]
  def change
    add_column :correspondence_threads, :show_in_list, :boolean, default: false, null: false
  end
end
```

### 2. モデルの変更

```ruby
# app/models/correspondence_thread.rb
class CorrespondenceThread < ApplicationRecord
  # 既存のスコープ
  scope :recent_order, -> { order(last_posted_at: :desc, created_at: :desc) }
  scope :public_threads, -> { where(status: [ "free", "paid" ]) }

  # 一覧表示対象（公開 かつ 一覧表示オン）
  # YAGNI原則に従い、シンプルに実装
  scope :discoverable, -> { public_threads.where(show_in_list: true) }
end
```

### 3. コントローラーの変更

```ruby
# app/controllers/threads_controller.rb
class ThreadsController < ApplicationController
  def index
    if logged_in?
      # パーソナライズドフィード（ログイン時）
      build_personalized_feed
    else
      # ランディングページ（ログアウト時）
      @threads = CorrespondenceThread.discoverable
                                     .includes(:users, :memberships)
                                     .recent_order
                                     .limit(6)
    end
  end

  def browse
    # 全交換日記一覧ページ
    @threads = CorrespondenceThread.discoverable
                                   .includes(:users, :memberships)
                                   .recent_order
  end
end
```

### 4. ビューの変更

#### スレッド作成・編集フォーム

`app/views/threads/new.html.slim` と `app/views/threads/edit.html.slim` に以下を追加：

```slim
.border.border-gray-200.rounded-lg.p-4.bg-gray-50
  label.flex.items-start.gap-3.cursor-pointer
    = f.check_box :show_in_list, class: "mt-1"
    .flex-1
      .text-sm.font-medium.text-gray-900
        | この交換日記を一覧ページに表示する
      .text-xs.text-gray-500.mt-1
        | 💡 一覧に表示しない場合でも、この交換日記は公開されています。
        br
        | 　 URLを知っている人は誰でも閲覧できます。非公開ではありませんのでご注意ください。
```

**注**: 現在は `new.html.slim` と `edit.html.slim` の両方に同じコードがありますが、将来的にはパーシャルに切り出すことを推奨します。

#### スレッド詳細ページ（一覧表示状態バッジ）

`app/views/threads/show.html.slim` に以下を追加：

```slim
/ 公開状態バッジ（メンバー向け）
- if is_member
  .mb-3.flex.flex-wrap.items-center.gap-2
    - if @thread.free? || @thread.paid?
      span.inline-flex.items-center.gap-1.text-xs.bg-green-100.text-green-800.rounded.px-2.py-1
        | 🌐 公開中
    - else
      span.inline-flex.items-center.gap-1.text-xs.bg-red-50.text-gray-700.rounded.px-2.py-1
        | 🔒 非公開
    - if @thread.show_in_list?
      span.inline-flex.items-center.gap-1.text-xs.bg-blue-50.text-blue-700.rounded.px-2.py-1
        | 📋 一覧表示中
```

### 5. Strong Parameters

```ruby
# app/controllers/threads_controller.rb
def thread_params
  # status の変更は toggle_published 経由のみ許可（編集フォームからは変更不可）
  params.require(:thread).permit(
    :title,
    :slug,
    :description,
    :turn_based,
    :thumbnail,
    :show_in_list  # 追加
  )
end
```

## 実装の流れ

1. ブランチを作成: `git checkout -b feature/optional-thread-listing`
2. マイグレーションを作成・実行
3. モデルにスコープを追加
4. コントローラーを変更（`index` で `discoverable` スコープを使用）
5. フォームにチェックボックスを追加
6. Strong Parameters に `show_in_list` を追加
7. 既存のビューを確認（一覧が空の場合のメッセージ）
8. テスト実行
9. 本番デプロイ

## マイグレーション手順（本番）

1. マイグレーションを実行（`show_in_list` カラム追加、デフォルト `false`）
2. アプリケーションを再起動（新コードをデプロイ）
3. 既存のスレッドはすべて `show_in_list: false` となり、一覧に表示されなくなる
4. スレッドのオーナーが編集画面で「一覧表示」をオンにすると、一覧に表示される

### 既存データの扱い

**重要な判断**: 既存のスレッドをどうするか？

#### 案1: すべて `false` でスタート（推奨）
- 既存スレッドも一覧に表示されなくなる
- オーナーが明示的に「一覧表示オン」を選ばない限り、しずかに続けられる
- **メリット**: 既存ユーザーに突然の露出変更がない、安全
- **デメリット**: 一覧が一時的に空になる

#### 案2: 既存スレッドは `true` にする
- 既存の公開スレッドは引き続き一覧に表示
- 新規スレッドのみデフォルト `false`
- **メリット**: 一覧が空にならない、既存の発見性を維持
- **デメリット**: 既存ユーザーが意図しない露出変更を受ける可能性

**推奨**: 案1（すべて `false` でスタート）
- 既存ユーザーへの影響を最小化
- 「しずかなインターネット」の思想に合致
- オーナーが明示的に選択できる

もし案1で進める場合、以下のようなアナウンスをユーザーに送る：

```
【coconikki 機能アップデートのお知らせ】

交換日記の一覧表示が選択式になりました。

今後、新規作成した交換日記はデフォルトで一覧に表示されません。
一覧に表示したい場合は、編集画面で「この交換日記を一覧ページに表示する」にチェックを入れてください。

既存の交換日記も、一覧表示をオフにした状態になっています。
引き続き一覧に表示したい場合は、編集画面でチェックを入れてください。

なお、一覧に表示しない場合でも、交換日記は公開されており、
URLを知っている人は誰でも閲覧できます。

詳しくは利用規約・プライバシーポリシーをご確認ください。
```

## 将来的な拡張

### フィルター機能
一覧表示されるスレッドが増えてきたら：
- タグによる分類
- 新着順・人気順・更新順などのソート
- 検索機能

### 発見性の向上
- おすすめスレッド機能
- 関連スレッドの提案
- RSS フィード（全体 / タグ別）

## テストケース

### 一覧表示オン/オフ
- [ ] デフォルトで `show_in_list: false`
- [ ] チェックを入れると `show_in_list: true`
- [ ] 一覧表示オンのスレッドは `/` と `/threads` に表示される
- [ ] 一覧表示オフのスレッドは一覧に表示されない
- [ ] 一覧表示オフでも、URLでアクセスできる

### 権限
- [ ] スレッドのメンバーのみが `show_in_list` を変更できる
- [ ] 非メンバーは変更できない

### 既存データ
- [ ] マイグレーション後、すべての既存スレッドが `show_in_list: false`
- [ ] 既存スレッドのオーナーが編集で `true` に変更できる

## 注意事項

### 電気通信事業法との整合性
- **すべてのスレッドが公開されている**: `show_in_list` に関わらず、URLを知っていればアクセス可能
- **一覧表示は「発見性」の問題**: 公開/非公開とは別の概念
- **注意書きで誤解を防ぐ**: 「非公開ではない」ことを明示

### ユーザーへの説明
- 「一覧に出ない = 非公開」ではないことを明確に伝える
- URLを共有すれば誰でも読めることを理解してもらう
- 完全非公開が必要な場合は、coconikkiではなく別のサービスを使うべき

## 完了条件

- [ ] マイグレーション実行
- [ ] モデルにスコープ追加
- [ ] コントローラー変更
- [ ] フォームにチェックボックス追加
- [ ] 注意書き表示
- [ ] テスト実行（全て通過）
- [ ] 既存ユーザーへのアナウンス準備
- [ ] 本番デプロイ
- [ ] 利用規約・プライバシーポリシーの更新（必要に応じて）
