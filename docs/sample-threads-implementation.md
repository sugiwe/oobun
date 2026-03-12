# サンプル交換日記の実装方針

作成日: 2026-03-12

## 目的

coconikkiを初めて見るユーザーに対して、「交換日記でどんなことが書けるのか」を具体的に示すため、サンプル交換日記を3種類用意する。

**狙い：**
- 「こういうのもありなんだ」と思ってもらう
- 「こういう感じなら書けそうだし面白そう」と感じてもらう
- coconikkiの可能性と使い方のバリエーションを伝える

---

## データ設計

### 1. テーブル設計

**既存の `correspondence_threads` テーブルを使用**

新しいカラムを追加：
```ruby
# マイグレーション
add_column :correspondence_threads, :is_sample, :boolean, default: false, null: false
add_index :correspondence_threads, :is_sample
```

**別テーブルにしない理由：**
- モデル構造が同じなので、別テーブルにするメリットが少ない
- 既存のアソシエーション（User, Post, Membership）をそのまま使える
- スコープで簡単に分離できる
- Rails wayに沿った設計

### 2. モデルへのスコープ追加

```ruby
# app/models/correspondence_thread.rb
scope :sample_threads, -> { where(is_sample: true) }
scope :user_threads, -> { where(is_sample: false) }
```

### 3. コントローラーでの分離

```ruby
# app/controllers/threads_controller.rb
def index
  # サンプル交換日記（最大3件、固定表示）
  @sample_threads = CorrespondenceThread.sample_threads
                                        .discoverable
                                        .recent_order
                                        .limit(3)

  # ユーザーの交換日記（ページネーション付き）
  @user_threads = CorrespondenceThread.user_threads
                                      .discoverable
                                      .recent_order
                                      .page(params[:page])
end

def browse
  # 全交換日記一覧ページでも同様に分離
  @sample_threads = CorrespondenceThread.sample_threads
                                        .discoverable
                                        .recent_order
                                        .limit(3)

  @user_threads = CorrespondenceThread.user_threads
                                      .discoverable
                                      .recent_order
                                      .page(params[:page])
end
```

---

## UI設計

### トップページ（index）とbrowseページ

サンプル交換日記を別セクションで表示：

```slim
/ サンプル交換日記セクション
- if @sample_threads.present?
  .mb-12
    .flex.items-center.justify-between.mb-4
      h2.text-lg.font-medium サンプル交換日記
      span.text-xs.text-gray-500 coconikkiの使い方の例です
    = render "threads/thread_grid", threads: @sample_threads

/ ユーザーの交換日記セクション
.mb-12
  h2.text-lg.font-medium.mb-4 交換日記一覧
  - if @user_threads.empty?
    .text-center.py-16.text-gray-400
      p.text-lg まだ交換日記がありません
      - if logged_in?
        p.text-sm.mt-2
          | 最初の交換日記を
          = link_to "作成する", new_thread_path, class: "underline"
          | ？
  - else
    = render "threads/thread_grid", threads: @user_threads
    .flex.justify-center.mt-8
      = paginate @user_threads
```

### デザイン上の配慮

- サンプル交換日記には「サンプル」バッジを表示（検討中）
- サンプル交換日記は常に上部に固定表示
- ユーザーの交換日記と視覚的に区別できるようにする

---

## Seedデータでの実装

### 実装方針

`db/seeds.rb` または `db/seeds/sample_threads.rb` でサンプルデータを作成。

**利点：**
- 一度作れば何度でも再現可能（開発環境でリセットして試せる）
- 本番環境にも同じデータを投入できる
- メンテナンスしやすい（内容変更が容易）
- 投稿日時も制御できる（リアルな時間経過を演出できる）

### Seed実装の流れ

1. サンプル用のユーザーを作成（6人程度）
   - username, display_name, bio, avatar URLなど設定
   - Google OAuth用のprovider/uidはダミー値
2. 3つのスレッドを作成
   - 各スレッドに異なるテーマとメンバー構成
   - `is_sample: true` を設定
   - `status: "free"`, `show_in_list: true` に設定
3. 各スレッドに5〜6投稿を時系列順に作成
   - タイトルと本文（300〜500文字）を設定
   - `status: "published"` で作成
   - created_atを調整して時間経過を演出

### 注意点

- ターン制のロジックは無視（一気に全投稿を作成）
- モデルのバリデーションは通る範囲で設定
- サンプルユーザーはログインできないようにする（OAuth認証のため実質不可能）

---

## サンプル交換日記の構成

### パターン1：「読んでいる本をゆっくり消化する」

**テーマ：** 『三体』を読み進めながら感想を交換
**メンバー：**
- さくら（@sakura_dev）: 30代、Webエンジニア、SF好き
- けんた（@kenta_design）: 20代、UIデザイナー、SF初心者

**投稿数：** 6往復
**狙い：** 共通の趣味を深掘りする、SNSより深い対話の見本

---

### パターン2：「同じ挑戦をしている人同士の実況」

**テーマ：** 週3回のランニング習慣をつける（1ヶ月チャレンジ）
**メンバー：**
- あゆみ（@ayumi_writer）: フリーライター、運動不足を自覚
- たける（@takeru_photo）: フォトグラファー、体力づくりが目的

**投稿数：** 6往復
**狙い：** 日常的な挑戦を報告し合う使い方。程よいプレッシャーとモチベーション維持

---

### パターン3：「全然違う立場の人同士の対話」

**テーマ：** 「AIについて思うこと」を異なる職種から語る
**メンバー：**
- まい（@mai_teacher）: 小学校教員、30代
- りょう（@ryo_engineer）: AI系スタートアップエンジニア、20代

**投稿数：** 6往復
**狙い：** 異なる視点からの対話が生む発見。読者にとって「読み物」として面白いコンテンツ

---

## 実装スケジュール

1. ✅ 実装方針のドキュメント作成
2. [ ] サンプル交換日記の内容ドキュメント作成（3パターン全投稿）
3. [ ] 内容の最終調整（ユーザーレビュー）
4. [ ] マイグレーション作成（is_sampleカラム追加）
5. [ ] モデルにスコープ追加
6. [ ] Seedファイル作成
7. [ ] コントローラー修正（index, browse）
8. [ ] ビュー修正（サンプルセクション追加）
9. [ ] 開発環境でSeed実行＆動作確認
10. [ ] 本番環境へのデプロイ

---

## 将来的な拡張案

- サンプル交換日記専用のバッジ表示
- サンプル交換日記の「テンプレートとして使う」機能（ユーザーが同じテーマで始められる）
- サンプル交換日記の定期的な入れ替え
- ユーザー投票で人気のあった交換日記をサンプルに昇格させる機能
