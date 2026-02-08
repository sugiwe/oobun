# 実装方針

## Rails プロジェクト構成

```bash
rails new oobun \
  --database=postgresql \
  --css=tailwind \
  --skip-test \
  --no-skip-bundle

# 追加設定
# - Slim: Gemfile に gem 'slim-rails' 追加後 bundle install
# - RSpec: Gemfile に gem 'rspec-rails' 追加後 rails generate rspec:install
```

**採用技術**

- データベース: PostgreSQL
- CSS フレームワーク: Tailwind CSS
- テンプレートエンジン: Slim
- テストフレームワーク: RSpec

---

## 設計上の注意・思想

- モデル名は一般的・堅実に（Thread / Post / Subscription）
- 文通らしさ・情緒は UI 文言で表現
- 将来の有料化・クローズド化を阻害しない設計
- チャット化しない（リアルタイム前提にしない）
- **RESTful 設計を優先**: 可能な限りリソースベースで表現し、Rails の CRUD に沿う

---

## 初期実装の制約

- 投稿の編集・削除は不可(将来検討)
- 通知機能なし(トップページで新着確認のみ)
- Thread は完全公開のみ(visibility = public 固定)
- Membership の role は writer のみ
- 画像アップロード機能なし
- OGP 画像は固定のアプリアイコンを使用

---

## UI/UX 方針

- Rails way に沿ったシンプルな実装
- Hotwire で部分更新・SPA 的な体験を実現
- 残り文字数表示(1,000文字を切ったら表示)
- モバイルフレンドリーなデザイン

---

## 非目標（今はやらない）

- リアルタイム通信
- DM 機能
- 複雑な通知設計
- 有料決済
- 画像アップロード機能
- 投稿の編集・削除機能

---

## 実装優先順位

### Phase 1: MVP

1. User 認証(Google OAuth)
2. User 登録時に username 設定
3. Thread CRUD(公開のみ、slug 対応、予約語チェック)
4. Membership(position 対応、role は writer のみ)
5. Post CRUD(show 含む、編集・削除なし、10,000文字制限)
6. 交代制ロジック(position ベース) + スキップ機能
7. RSS フィード(個別スレッド単位: `/:slug.rss`)
8. トップページ(`/`: 全体公開 Thread 一覧、最近更新順)
9. Thread 詳細ページ(`/:slug`: Post 抜粋一覧、購読ボタン、RSS リンク)
10. Post 詳細ページ(`/:slug/:post_id`: 全文表示、前後ナビ)
11. ユーザーページ(`/@username`)

### Phase 2: コミュニティ機能

1. Subscription 機能(購読/購読解除)
2. 購読中 Thread 一覧(トップページ)
3. ページネーション改善(Pagy gem 等)
4. 検索機能(Thread タイトル・本文)

### Phase 3: 品質向上

1. OGP 対応(カスタム画像生成)
2. 編集・削除機能の検討
3. 下書き機能
4. visibility の拡張(url_only, followers_only 等)
