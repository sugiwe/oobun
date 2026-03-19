# モデルテスト設計書

**作成日**: 2026-03-19
**目的**: coconikkiの全モデルに対する包括的なテスト戦略とテストケース一覧

---

## テスト方針

### 基本ポリシー

1. **テストの優先順位**
   - コアビジネスロジック > バリデーション > アソシエーション > スコープ
   - 複雑なロジックを持つメソッドを優先
   - エッジケース・境界値を重点的にテスト

2. **テストの粒度**
   - 1つのテストケースは1つの振る舞いのみを検証
   - describeブロックで論理的にグループ化
   - contextで条件分岐を明確化

3. **テストデータ**
   - FactoryBotでデータ作成
   - Fakerでランダムデータ生成
   - 最小限のデータで最大限の検証

### RSpecの構造

```ruby
RSpec.describe ModelName, type: :model do
  # 1. バリデーション
  describe 'validations' do
  end

  # 2. アソシエーション
  describe 'associations' do
  end

  # 3. スコープ
  describe 'scopes' do
  end

  # 4. インスタンスメソッド
  describe '#method_name' do
  end

  # 5. クラスメソッド
  describe '.method_name' do
  end

  # 6. コールバック
  describe 'callbacks' do
  end
end
```

---

## モデル一覧と優先順位

| 優先度 | モデル               | 理由                         | 複雑度 |
| ------ | -------------------- | ---------------------------- | ------ |
| 🥇 高  | User                 | 認証・制限ロジックの要       | 高     |
| 🥇 高  | CorrespondenceThread | 交代制・公開制御の中核       | 高     |
| 🥇 高  | Post                 | ステータス管理・公開ロジック | 中     |
| 🥇 高  | Membership           | 交代順序管理                 | 中     |
| 🥈 中  | Subscription         | シンプルな購読管理           | 低     |
| 🥈 中  | Skip                 | ターンスキップロジック       | 低     |
| 🥉 低  | AllowedUser          | 補助的                       | 低     |
| 🥉 低  | LoginInvitation      | 補助的                       | 低     |
| 🥉 低  | Invitation           | 補助的                       | 低     |

---

## 各モデルの詳細テストケース

---

## 1. User（優先度: 🥇 高）

### 概要

- 認証の起点
- 投稿制限・ストレージ制限・スレッド参加制限
- パーソナライズフィード生成

### バリデーション

#### presence

- [ ] username が必須
- [ ] display_name が必須
- [ ] email が必須

#### uniqueness

- [ ] username がユニーク
- [ ] email がユニーク
- [ ] google_uid がユニーク（nil許可）

#### format

- [ ] username が英数字・ハイフン・アンダースコアのみ
- [ ] username が不正な文字（スペース、記号など）を含む場合エラー

#### length

- [ ] username が3文字未満でエラー
- [ ] username が20文字を超えるとエラー
- [ ] username が3〜20文字で有効
- [ ] display_name が50文字以内で有効
- [ ] display_name が50文字を超えるとエラー
- [ ] bio が5000文字以内で有効
- [ ] bio が5000文字を超えるとエラー

#### avatar

- [ ] 画像形式が png, jpeg, gif, webp で有効
- [ ] 画像サイズが5MB未満で有効
- [ ] 画像サイズが5MB以上でエラー
- [ ] ストレージ上限を超える画像アップロードでエラー

### アソシエーション

- [ ] has_many :memberships (dependent: :destroy)
- [ ] has_many :correspondence_threads (through: :memberships)
- [ ] has_many :posts (unscopeでdraft含む)
- [ ] has_many :published_posts
- [ ] has_many :draft_posts
- [ ] has_many :subscriptions (dependent: :destroy)
- [ ] has_many :subscribed_threads (through: :subscriptions)
- [ ] has_many :skips (dependent: :destroy)
- [ ] has_one_attached :avatar

### クラスメソッド

#### `.find_or_initialize_from_google(payload)`

- [ ] 既存ユーザーの場合、emailを更新してユーザーを返す
- [ ] 新規ユーザーの場合、Google情報を設定して返す
- [ ] 新規ユーザーの場合、usernameは設定されない（別画面で設定）

### インスタンスメソッド

#### `#can_join_thread?`

- [ ] スレッド参加数が上限未満の場合true
- [ ] スレッド参加数が上限に達している場合false

#### `#threads_remaining`

- [ ] 正しい残り参加可能数を返す
- [ ] 上限に達している場合0を返す

#### `#storage_used`

- [ ] アバター画像のサイズを含む
- [ ] 投稿のサムネイル画像のサイズを含む
- [ ] 画像がない場合0を返す

#### `#storage_remaining`

- [ ] 正しい残りストレージ容量を返す

#### `#can_upload?(file_size)`

- [ ] アップロード後も上限以内ならtrue
- [ ] アップロード後に上限を超える場合false

#### `#post_rate_limit_exceeded?`

- [ ] 1時間以内の投稿が上限未満ならfalse
- [ ] 1時間以内の投稿が上限に達している場合true
- [ ] 1日の投稿が上限未満ならfalse
- [ ] 1日の投稿が上限に達している場合true

#### `#posts_in_last_hour`

- [ ] 1時間以内の投稿数を正確にカウント（draft含む）
- [ ] 1時間より古い投稿は含まない

#### `#posts_today`

- [ ] 日本時間0時以降の投稿数を正確にカウント（draft含む）
- [ ] 前日の投稿は含まない

#### `#admin?`

- [ ] ADMIN_EMAILSに含まれるメールの場合true
- [ ] ADMIN_EMAILSに含まれないメールの場合false

#### `#deleted?`

- [ ] deleted_atがnilの場合false
- [ ] deleted_atが設定されている場合true

#### `#normalized_email`

- [ ] メールアドレスを小文字に変換
- [ ] 前後の空白を削除

#### `#personalized_feed_data`

- [ ] 自分のターンの投稿を取得
- [ ] 参加中のスレッドを取得
- [ ] フォロー中のスレッドを取得（参加中を除く）
- [ ] 新着投稿を取得

---

## 2. CorrespondenceThread（優先度: 🥇 高）

### 概要

- 文通の中心モデル
- 交代制ロジック
- 自動公開ロジック

### バリデーション

#### presence

- [ ] title が必須
- [ ] slug が必須
- [ ] status が必須

#### uniqueness

- [ ] slug がユニーク

#### format

- [ ] slug が英数字とハイフンのみ
- [ ] slug が不正な文字を含む場合エラー

#### length

- [ ] slug が3文字未満でエラー
- [ ] slug が50文字を超えるとエラー
- [ ] slug が3〜50文字で有効

#### inclusion

- [ ] status が draft, free, paid のいずれかで有効
- [ ] status が不正な値でエラー
- [ ] turn_based が true または false で有効

#### custom validation

- [ ] slug が予約語の場合エラー
- [ ] slug が予約語でない場合有効

#### thumbnail

- [ ] 画像形式が png, jpeg, gif, webp で有効
- [ ] 画像サイズが5MB未満で有効
- [ ] 画像サイズが5MB以上でエラー

### アソシエーション

- [ ] has_many :memberships (dependent: :destroy)
- [ ] has_many :users (through: :memberships)
- [ ] has_many :posts (unscopeでdraft含む)
- [ ] has_many :published_posts
- [ ] has_many :draft_posts
- [ ] has_many :subscriptions (dependent: :destroy)
- [ ] has_many :subscribers (through: :subscriptions)
- [ ] has_many :skips (dependent: :destroy)
- [ ] has_many :invitations (dependent: :destroy)
- [ ] has_one_attached :thumbnail

### Enum

- [ ] status が draft, free, paid を持つ
- [ ] draft? が正しく動作
- [ ] free? が正しく動作
- [ ] paid? が正しく動作

### スコープ

#### `.recent_order`

- [ ] last_posted_at 降順でソート
- [ ] last_posted_atが同じ場合created_at降順

#### `.public_threads`

- [ ] status が free または paid のみ
- [ ] draft は含まない

#### `.discoverable`

- [ ] 公開スレッド かつ show_in_list が true
- [ ] show_in_list が false は含まない

#### `.sample_threads`

- [ ] is_sample が true のみ

#### `.user_threads`

- [ ] is_sample が false のみ

### インスタンスメソッド

#### `#current_turn_user`

- [ ] turn_basedがfalseの場合nil
- [ ] 投稿がない場合、position 1 のユーザー
- [ ] 2人の場合、交代でターンが巡る
- [ ] 3人以上の場合、position順にターンが巡る
- [ ] 最大positionの次は position 1 に戻る

#### `#my_turn?(user)`

- [ ] turn_basedがfalseの場合常にtrue
- [ ] current_turn_userと一致する場合true
- [ ] current_turn_userと一致しない場合false

#### `#member?(user)`

- [ ] メンバーの場合true
- [ ] メンバーでない場合false
- [ ] userがnilの場合false

#### `#editable_by?(user)`

- [ ] メンバーの場合true
- [ ] メンバーでない場合false

#### `#draft_for(user)`

- [ ] 指定ユーザーの下書きを返す
- [ ] 下書きがない場合nil

#### `#has_draft_for?(user)`

- [ ] 下書きがある場合true
- [ ] 下書きがない場合false

#### `#visible_posts_for(user)`

- [ ] ユーザー指定時、公開済み + 匿名化済み + 自分の下書きを返す
- [ ] ユーザー未指定時、公開済み投稿のみ返す

#### `#update_last_post_metadata!`

- [ ] 最新の公開投稿のuser_idとcreated_atを設定
- [ ] excluded_post_id指定時、そのpostを除外
- [ ] 公開投稿がない場合、nilを設定

#### `#toggle_published!`

- [ ] free状態からdraftに変更
- [ ] paid状態からdraftに変更
- [ ] draft状態からfreeに変更

#### `#viewable_by?(user)`

- [ ] メンバーの場合常にtrue
- [ ] freeの場合true
- [ ] paidの場合true（Phase 3で購読チェック追加予定）
- [ ] draftかつ非メンバーの場合false

#### `#auto_publish!`

- [ ] draft状態からfreeに変更
- [ ] ログに記録
- [ ] draft以外では何もしない

#### `#days_since_creation`

- [ ] 作成からの経過日数を正確に計算

#### `#can_be_privatized?`

- [ ] draft状態の場合false
- [ ] 5投稿未満 かつ 30日未満の場合true
- [ ] 5投稿以上の場合false
- [ ] 30日以上経過している場合false

#### `#to_export_json`

- [ ] スレッド情報を含むJSON生成
- [ ] メンバー情報を含む
- [ ] 投稿情報を含む
- [ ] サムネイル情報を含む

#### `#export_with_images_zip`

- [ ] JSON + 画像を含むZIPファイル生成
- [ ] スレッドサムネイルを含む
- [ ] 投稿サムネイルを含む

---

## 3. Post（優先度: 🥇 高）

### 概要

- コンテンツの本体
- ステータス管理（draft, published, anonymized）
- スレッド自動公開トリガー

### Enum

- [ ] status が draft, published, anonymized を持つ
- [ ] デフォルトが published
- [ ] draft? が正しく動作
- [ ] published? が正しく動作
- [ ] anonymized? が正しく動作

### バリデーション

#### presence (published時のみ)

- [ ] published状態でtitleが必須
- [ ] published状態でbodyが必須
- [ ] draft状態ではtitle任意
- [ ] draft状態ではbody任意

#### length

- [ ] title が100文字以内で有効
- [ ] title が100文字を超えるとエラー
- [ ] published状態でbodyが10文字未満でエラー
- [ ] published状態でbodyが10,000文字を超えるとエラー
- [ ] published状態でbodyが10〜10,000文字で有効
- [ ] draft状態ではbodyが10,000文字以内なら有効

#### thumbnail

- [ ] 画像形式が png, jpeg, gif, webp で有効
- [ ] 画像サイズが5MB未満で有効
- [ ] 画像サイズが5MB以上でエラー
- [ ] ユーザーのストレージ上限を超える場合エラー

### アソシエーション

- [ ] belongs_to :thread
- [ ] belongs_to :user
- [ ] has_one_attached :thumbnail

### スコープ

#### `.published_posts`

- [ ] status が published または anonymized
- [ ] created_at 昇順でソート
- [ ] draft は含まない

#### `.draft_posts`

- [ ] status が draft のみ

#### default_scope

- [ ] デフォルトで published_posts スコープが適用される
- [ ] unscope で draft も取得可能

### インスタンスメソッド

#### `#prev`

- [ ] 作成日時が古い順で前の公開投稿を返す
- [ ] 前の投稿がない場合nil
- [ ] draftは含まない

#### `#next`

- [ ] 作成日時が新しい順で次の公開投稿を返す
- [ ] 次の投稿がない場合nil
- [ ] draftは含まない

#### `#editable_by?(user)`

- [ ] 作成者の場合true
- [ ] 作成者以外の場合false
- [ ] userがnilの場合false

#### `#publish!`

- [ ] statusをpublishedに変更
- [ ] 保存される

#### `#can_publish?(user)`

- [ ] draft かつ 作成者 かつ 自分のターンの場合true
- [ ] published状態の場合false
- [ ] 作成者以外の場合false
- [ ] 自分のターンでない場合false

### コールバック

#### after_commit (status変更時)

- [ ] draft → published 変更時、スレッドの自動公開をチェック
- [ ] スレッドがdraft かつ 5投稿以上で自動公開
- [ ] create時にも動作

---

## 4. Membership（優先度: 🥇 高）

### 概要

- スレッド参加管理
- 交代順序（position）管理

### バリデーション

#### presence

- [ ] position が必須
- [ ] role が必須

#### uniqueness

- [ ] position がスレッド内でユニーク
- [ ] user_id がスレッド内でユニーク（重複参加防止）

#### inclusion

- [ ] role が writer で有効
- [ ] role が writer 以外でエラー

### アソシエーション

- [ ] belongs_to :user
- [ ] belongs_to :thread

---

## 5. Subscription（優先度: 🥈 中）

### 概要

- スレッド購読管理

### バリデーション

#### uniqueness

- [ ] user_id がスレッド内でユニーク（重複購読防止）

### アソシエーション

- [ ] belongs_to :user
- [ ] belongs_to :thread

---

## 6. Skip（優先度: 🥈 中）

### 概要

- ターンスキップ機能

### アソシエーション

- [ ] belongs_to :user
- [ ] belongs_to :thread

### スコープ

#### `.recent`

- [ ] created_at 降順でソート

### コールバック

#### after_create

- [ ] スレッドの last_post_user_id をスキップしたユーザーに更新
- [ ] 次のターンに進む

---

## テスト実装の進め方

### Phase 1: 環境整備

1. Gemfile に gem 追加（factory_bot_rails, faker, shoulda-matchers）
2. bundle install
3. spec/support/factory_bot.rb, spec/support/shoulda_matchers.rb 作成
4. rails_helper.rb に設定追加

### Phase 2: User モデル完成

1. spec/factories/users.rb 作成
2. spec/models/user_spec.rb 実装
3. 全テスト緑にする

### Phase 3: 順次拡大

1. CorrespondenceThread
2. Post
3. Membership
4. Subscription
5. Skip

### Phase 4: カバレッジ確認

- SimpleCov 導入（オプション）
- カバレッジ80%以上を目標

---

## 参考資料

- RSpec公式: https://rspec.info/
- FactoryBot公式: https://github.com/thoughtbot/factory_bot
- Shoulda Matchers公式: https://github.com/thoughtbot/shoulda-matchers
- Better Specs: https://www.betterspecs.org/

---

## 更新履歴

- 2026-03-19: 初版作成
