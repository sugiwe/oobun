# HTMLメールのCSS互換性改善（premailer-rails導入）

**作成日:** 2026-03-30
**優先度:** 中
**工数見積:** 2〜3時間
**影響範囲:** 全メールテンプレート

## 背景

PR #90のコードレビュー（Gemini）で指摘された問題：

> HTMLメールのスタイリングについて、多くのメールクライアントは`<head>`や`<style>`タグをサポートしていないか、部分的にしかサポートしていません。そのため、CSSが適用されない可能性があります。

現状、HTMLメールテンプレート（`app/views/user_mailer/*.html.slim`）では、`<head>`内の`<style>`タグでCSSを定義していますが、以下のメールクライアントでスタイルが適用されない可能性があります：

- Gmail（一部のCSSプロパティのみサポート）
- Outlookシリーズ（特に古いバージョン）
- Yahoo! Mail
- その他モバイルメールクライアント

## 目標

全メールクライアントで一貫したデザインを表示できるよう、**CSSをインラインスタイルに自動変換**する仕組みを導入します。

## 解決策：premailer-rails の導入

### premailer-rails とは

- RailsのActionMailerと統合されたgemで、メール送信時に自動的にCSSをインラインスタイルに変換
- `<style>`タグ内のCSSを各HTML要素の`style`属性に展開
- メールクライアントの互換性を大幅に向上

### 実装手順

#### 1. Gemのインストール

**Gemfile に追加:**
```ruby
gem 'premailer-rails'
```

**インストール:**
```bash
bundle install
```

#### 2. 設定（オプション）

必要に応じて `config/initializers/premailer_rails.rb` を作成：

```ruby
Premailer::Rails.config.merge!(
  # CSSの削除（インライン化後に<style>タグを残すか）
  remove_ids: false,
  remove_classes: false,

  # メディアクエリの扱い
  preserve_styles: true,

  # CSSファイルの読み込み（必要な場合）
  # css: [:file, :string]
)
```

#### 3. 既存テンプレートの確認

現在のHTMLメールテンプレート：
- `app/views/user_mailer/new_post_notification.html.slim`
- `app/views/user_mailer/daily_digest.html.slim`
- `app/views/user_mailer/test_notification.html.slim`

**変更不要** - premailer-railsが自動的に処理します。

#### 4. 動作確認

**ローカル環境でテスト:**
```bash
# メール送信テスト
bin/rails console

# テストメール送信
user = User.first
notification = user.notifications.create!(
  actor: user,
  notifiable: user,
  action: :test_notification,
  params: { message: "premailer-railsテスト" }
)

UserMailer.test_notification(notification).deliver_now
```

**確認ポイント:**
1. 送信されたメールのHTMLソースを確認
2. `<style>`タグのCSSが各要素の`style`属性に展開されているか
3. 元の`<style>`タグが残っているか（設定による）

#### 5. 各種メールクライアントでの表示確認

**推奨テスト環境:**
- Gmail（Webブラウザ版）
- Gmail（モバイルアプリ）
- Outlook（Windows）
- Apple Mail（macOS/iOS）
- Yahoo! Mail

**確認項目:**
- ✅ フォント、色、サイズが正しく表示される
- ✅ ボタンのスタイル（背景色、パディング、角丸）
- ✅ レイアウト（max-width、margin、padding）
- ✅ ボーダー、背景色

#### 6. デプロイ

本番環境でも同様にテストメールを送信して確認。

## 注意事項

### 1. メディアクエリの制限

多くのメールクライアントはメディアクエリをサポートしていません。レスポンシブデザインが必要な場合は、以下のアプローチを検討：

- **流体レイアウト**: パーセント幅を使用
- **モバイルファーストデザイン**: デフォルトでモバイル向けスタイルを適用
- **条件付きコメント**: Outlook用の特別な対応

### 2. パフォーマンスへの影響

premailer-railsはメール送信時にCSSを解析・変換するため、わずかにオーバーヘッドがあります。通常は問題になりませんが、大量配信時は考慮が必要です。

### 3. 既存メールへの影響

**重要:** 既存の3つのメールテンプレートすべてに影響するため、**必ず本番デプロイ前に各テンプレートの表示確認**を行ってください。

- `new_post_notification.html.slim`
- `daily_digest.html.slim`
- `test_notification.html.slim`

### 4. テキストメールは影響なし

`.text.slim`テンプレートには影響ありません。

## 完了条件

- [x] premailer-railsをインストール
- [x] 設定ファイル作成（必要に応じて）
- [x] ローカル環境でテストメール送信
- [x] HTMLソースでインラインスタイルを確認
- [x] 各メールクライアントで表示確認（最低3種類）
- [x] 既存3つのメールテンプレートすべてで確認
- [x] 本番環境でテストメール送信
- [x] ドキュメント更新（必要に応じて）

## 参考資料

- [premailer-rails GitHub](https://github.com/fphilipe/premailer-rails)
- [Email Client Market Share](https://www.emailclientmarketshare.com/)
- [CSS Support Guide for Email Clients](https://www.campaignmonitor.com/css/)
- [Can I email...](https://www.caniemail.com/) - メールクライアントのCSS互換性チェック

## 関連PR

- PR #90: 即時配信モードでテスト通知メールを送信可能に（このレビューで指摘された）

## 補足：なぜ今回のPRで対応しなかったか

1. **影響範囲が広い**: 既存の全メールテンプレート（3つ）に影響するため、慎重なテストが必要
2. **スコープ外**: PR #90の主目的は「テスト通知のメール送信機能追加」であり、CSS互換性改善は別の関心事
3. **段階的デプロイ**: 機能追加とメール品質改善を分けることで、問題の切り分けが容易になる

そのため、別PRとして対応することを推奨します。
