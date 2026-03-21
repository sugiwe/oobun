# 通知機能実装プラン

coconikkiの通知システム実装ガイドです。

---

## 📋 概要

### 目的

- ユーザーが参加/購読している文通の新着投稿を見逃さない
- アプリ内通知とDiscord/Slack通知の両方に対応
- 将来的にメール通知にも拡張可能

### 設計方針

- **gem不使用**: Noticed gemは使わず、シンプルな自前実装
- **Rails way**: 標準的なモデル・サービス・ジョブ構成
- **拡張性**: 新しい通知タイプや配信チャネルを簡単に追加可能
- **非同期処理**: 外部通知はジョブで非同期実行

---

## 🎯 通知の種類

### Phase 1で実装
- **new_post**: 参加中/購読中の文通に新しい投稿があった

### 将来的に追加候補
- **invitation**: 文通への招待
- **mention**: @メンション
- **thread_published**: フォロー中のユーザーが新しい文通を公開

---

## 🏗️ アーキテクチャ

### データフロー

#### Phase 1a（現在）
```
Post作成（published のみ）
  ↓
after_commit :notify_subscribers (if: :published?)
  ↓
NotificationService.notify_new_post(post)
  ↓
受信者判定（メンバー + 購読者 - 投稿者）
  ↓
各受信者に対してNotification作成
  ↓
（Notification.after_create_commit は空実装）
```

#### Phase 2以降
```
Notification作成
  ↓
Notification.after_create_commit
  ↓
DiscordNotificationJob.perform_later (非同期)
  ↓
Discord Webhookへ送信
```

### モデル構成

```
User
  ├── notifications (受信した通知)
  ├── created_notifications (自分が引き起こした通知) as actor
  └── notification_setting

Notification
  ├── belongs_to :user (受信者)
  ├── belongs_to :actor (アクションを起こした人)
  └── belongs_to :notifiable (対象: Post, Membership等)

NotificationSetting
  └── belongs_to :user
```

---

## 📅 実装フェーズ

### Phase 1a: 通知の基盤とデータ構造 🎯 現在のフェーズ

**目標**: データ構造とビジネスロジックを確立（UIなし）

**ブランチ**: `feature/in-app-notifications`

#### タスク

1. **マイグレーション作成・実行**
   - [ ] `notifications` テーブル作成
   - [ ] `notification_settings` テーブル作成
   - [ ] マイグレーション実行

2. **モデル作成**
   - [ ] `Notification` モデル作成
   - [ ] `NotificationSetting` モデル作成
   - [ ] User への関連追加（`has_many :notifications`, `has_one :notification_setting`）
   - [ ] Post への関連追加（`has_many :notifications`）

3. **通知生成ロジック**
   - [ ] `NotificationService` 作成
   - [ ] 受信者判定ロジック（メンバー + 購読者 - 投稿者本人）
   - [ ] Post 作成時の通知生成（`after_commit :notify_subscribers, on: :create, if: :published?`）
   - [ ] 通知パラメータ生成（thread_title, thread_slug, post_preview）

4. **テスト作成**
   - [ ] Notification モデルテスト（RSpec）
   - [ ] NotificationSetting モデルテスト（RSpec）
   - [ ] NotificationService テスト（RSpec）
   - [ ] 統合テスト（Post作成 → Notification作成）

5. **動作確認**
   - [ ] Rails console で Post 作成 → Notification レコード確認
   - [ ] 受信者の正しさを確認（メンバー + 購読者 - 投稿者）
   - [ ] 通知パラメータの確認

#### 成果物
- ✅ Notification/NotificationSetting モデルが作成される
- ✅ 投稿すると自動的に Notification レコードが作成される
- ✅ データ構造が確立される
- ✅ テストで品質保証される
- ⚠️ UIはまだない（Rails consoleで確認）

#### 技術的改善ポイント

**N+1問題の回避**:
```ruby
# recipients メソッドの実装
def recipients
  User.where(id: member_ids + subscriber_ids)
      .where.not(id: @actor.id)
      .distinct
end

def member_ids
  @thread.memberships.pluck(:user_id)
end

def subscriber_ids
  @thread.subscriptions.pluck(:user_id)
end
```

**通知トリガー**:
```ruby
# Post モデル
after_commit :notify_subscribers, on: :create, if: :published?

# 理由:
# - 下書き投稿では通知不要
# - draft → published への移行時にも通知したい場合は別途検討
```

---

### Phase 1b: アプリ内通知UI

**目標**: ユーザーがブラウザで通知を確認できる

**前提**: Phase 1a が完了していること

#### タスク

1. **コントローラー作成**
   - [ ] `NotificationsController` 作成
     - `index`: 通知一覧
     - `show`: 通知詳細 → 対象ページへリダイレクト
     - `mark_as_read`: 個別既読
     - `mark_all_as_read`: 一括既読

2. **ビュー作成**
   - [ ] 通知一覧ページ（`app/views/notifications/index.html.slim`）
   - [ ] ヘッダーに通知アイコン追加（未読数バッジ）
   - [ ] 既読/未読の視覚的区別

3. **ルーティング追加**
   - [ ] `resources :notifications` 追加
   - [ ] カスタムアクション追加

4. **UI/UXの調整**
   - [ ] ページネーション（kaminari）
   - [ ] Turbo対応
   - [ ] レスポンシブデザイン

#### 成果物
- ✅ ブラウザで通知一覧が見れる
- ✅ ヘッダーに未読数バッジが表示される
- ✅ 既読/未読管理ができる
- ✅ 通知クリックで対象ページへ遷移

---

### Phase 2: Discord/Slack Webhook通知

**目標**: 外部サービスへの通知配信

#### タスク

1. **NotificationSetting拡張**
   - Discord Webhook URL設定
   - Slack Webhook URL設定（オプション）
   - 配信チャネル選択

2. **ジョブ作成**
   - `DiscordNotificationJob`
   - `SlackNotificationJob`（オプション）
   - リトライ・エラーハンドリング

3. **配信ロジック**
   - `Notification.after_create_commit`でジョブ呼び出し
   - Webhook送信処理
   - リッチメッセージフォーマット

4. **設定UI**
   - Webhook URL入力フォーム
   - テスト送信機能

#### 成果物
- Discord/Slackに通知が届く
- ユーザーがWebhook URLを設定可能
- 失敗してもアプリ内通知は残る

---

### Phase 3: 通知設定の詳細化（オプション）

**目標**: きめ細かい通知制御

#### タスク

1. **通知タイプごとのON/OFF**
   - 参加中の文通の新規投稿
   - 購読中の文通の新規投稿
   - 招待通知

2. **配信方法の選択**
   - タイプごとに配信チャネルを選択
   - 通知頻度制御（リアルタイム vs ダイジェスト）

3. **設定UI強化**
   - 詳細設定ページ
   - プレビュー機能

#### 成果物
- ユーザーが通知を細かく制御可能
- UX向上

---

### Phase 4: メール通知（オプション）

**目標**: メール経由での通知

#### タスク

1. **EmailDeliveryJob作成**
2. Action Mailerセットアップ
3. メールテンプレート作成
4. 配信頻度制御

#### 成果物
- メール通知対応

---

## 🔧 実装詳細

### 1. Migration

#### notifications テーブル

```ruby
# db/migrate/XXXXXX_create_notifications.rb
class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.references :notifiable, polymorphic: true, null: false
      t.string :action, null: false
      t.json :params
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [:user_id, :read_at]
    add_index :notifications, [:user_id, :created_at]
  end
end
```

#### notification_settings テーブル

```ruby
# db/migrate/XXXXXX_create_notification_settings.rb
class CreateNotificationSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_settings do |t|
      t.references :user, null: false, foreign_key: true

      # 通知タイプごとのON/OFF
      t.boolean :notify_member_posts, default: true
      t.boolean :notify_subscription_posts, default: true
      t.boolean :notify_invitations, default: true

      # Webhook設定
      t.string :discord_webhook_url
      t.string :slack_webhook_url
      t.boolean :use_discord, default: false
      t.boolean :use_slack, default: false

      t.timestamps
    end
  end
end
```

---

### 2. モデル

#### Notification

```ruby
# app/models/notification.rb
class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :notifiable, polymorphic: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  enum action: {
    new_post: "new_post",
    invitation: "invitation"
  }

  # Phase 2で有効化
  # after_create_commit :deliver_notifications

  def mark_as_read!
    update(read_at: Time.current)
  end

  def unread?
    read_at.nil?
  end

  private

  # Phase 2で実装
  # def deliver_notifications
  #   # Discord通知（非同期）
  #   if user.notification_setting&.use_discord?
  #     DiscordNotificationJob.perform_later(id)
  #   end
  #
  #   # Slack通知（非同期）
  #   if user.notification_setting&.use_slack?
  #     SlackNotificationJob.perform_later(id)
  #   end
  # end
end
```

#### NotificationSetting

```ruby
# app/models/notification_setting.rb
class NotificationSetting < ApplicationRecord
  belongs_to :user

  validates :discord_webhook_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[https]), allow_blank: true }
  validates :slack_webhook_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[https]), allow_blank: true }

  def discord_configured?
    discord_webhook_url.present? && use_discord?
  end

  def slack_configured?
    slack_webhook_url.present? && use_slack?
  end
end
```

#### User（追加）

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :notifications, dependent: :destroy
  has_many :created_notifications, class_name: "Notification", foreign_key: :actor_id, dependent: :nullify
  has_one :notification_setting, dependent: :destroy

  after_create :create_notification_setting

  def unread_notifications_count
    notifications.unread.count
  end

  private

  def create_notification_setting
    build_notification_setting.save!
  end
end
```

#### Post（追加）

```ruby
# app/models/post.rb
class Post < ApplicationRecord
  belongs_to :thread
  belongs_to :user
  has_many :notifications, as: :notifiable, dependent: :destroy

  # published な投稿のみ通知する
  after_commit :notify_subscribers, on: :create, if: :published?

  private

  def notify_subscribers
    NotificationService.notify_new_post(self)
  end
end
```

---

### 3. サービス

#### NotificationService

```ruby
# app/services/notification_service.rb
class NotificationService
  def self.notify_new_post(post)
    new(post).notify_new_post
  end

  def initialize(post)
    @post = post
    @thread = post.thread
    @actor = post.user
  end

  def notify_new_post
    recipients.each do |user|
      next unless should_notify?(user)

      Notification.create!(
        user: user,
        actor: @actor,
        notifiable: @post,
        action: :new_post,
        params: notification_params
      )
    end
  end

  private

  def recipients
    # N+1問題を回避：distinctで重複排除、一度のクエリで取得
    User.where(id: member_ids + subscriber_ids)
        .where.not(id: @actor.id)
        .distinct
  end

  def member_ids
    @thread.memberships.pluck(:user_id)
  end

  def subscriber_ids
    @thread.subscriptions.pluck(:user_id)
  end

  def should_notify?(user)
    setting = user.notification_setting
    return true unless setting # デフォルトは通知する

    # メンバーかどうかで判定
    if @thread.members.include?(user)
      setting.notify_member_posts
    else
      setting.notify_subscription_posts
    end
  end

  def notification_params
    {
      thread_title: @thread.title,
      thread_slug: @thread.slug,
      post_preview: @post.body.truncate(100)
    }
  end
end
```

---

### 4. ジョブ

#### DiscordNotificationJob

```ruby
# app/jobs/discord_notification_job.rb
class DiscordNotificationJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(notification_id)
    notification = Notification.find(notification_id)
    setting = notification.user.notification_setting

    return unless setting&.discord_configured?

    payload = build_payload(notification)

    HTTP.post(setting.discord_webhook_url, json: payload)
  rescue => e
    Rails.logger.error("Discord notification failed: #{e.message}")
    # 失敗してもアプリ内通知は残る
  end

  private

  def build_payload(notification)
    {
      embeds: [{
        title: "#{notification.actor.name}さんが投稿しました",
        description: notification.params["post_preview"],
        url: thread_url(notification.params["thread_slug"]),
        color: 3066993, # 緑
        fields: [
          {
            name: "文通",
            value: notification.params["thread_title"],
            inline: true
          }
        ],
        timestamp: notification.created_at.iso8601,
        footer: { text: "coconikki" }
      }]
    }
  end

  def thread_url(slug)
    Rails.application.routes.url_helpers.thread_url(slug, host: "coconikki.com")
  end
end
```

#### SlackNotificationJob（オプション）

```ruby
# app/jobs/slack_notification_job.rb
class SlackNotificationJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(notification_id)
    notification = Notification.find(notification_id)
    setting = notification.user.notification_setting

    return unless setting&.slack_configured?

    payload = build_payload(notification)

    HTTP.post(setting.slack_webhook_url, json: payload)
  rescue => e
    Rails.logger.error("Slack notification failed: #{e.message}")
  end

  private

  def build_payload(notification)
    {
      blocks: [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*#{notification.actor.name}さんが投稿しました*\n#{notification.params['post_preview']}"
          }
        },
        {
          type: "context",
          elements: [
            {
              type: "mrkdwn",
              text: "文通: #{notification.params['thread_title']}"
            }
          ]
        },
        {
          type: "actions",
          elements: [
            {
              type: "button",
              text: {
                type: "plain_text",
                text: "投稿を見る"
              },
              url: thread_url(notification.params["thread_slug"])
            }
          ]
        }
      ]
    }
  end

  def thread_url(slug)
    Rails.application.routes.url_helpers.thread_url(slug, host: "coconikki.com")
  end
end
```

---

### 5. コントローラー

#### NotificationsController

```ruby
# app/controllers/notifications_controller.rb
class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @notifications = current_user.notifications
                                  .recent
                                  .includes(:actor, :notifiable)
                                  .page(params[:page])
                                  .per(20)
  end

  def mark_as_read
    notification = current_user.notifications.find(params[:id])
    notification.mark_as_read!

    redirect_to notification_path(notification)
  end

  def mark_all_as_read
    current_user.notifications.unread.update_all(read_at: Time.current)

    redirect_to notifications_path, notice: "すべての通知を既読にしました"
  end

  def show
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_as_read! if @notification.unread?

    # 通知対象にリダイレクト
    redirect_to notification_target_path(@notification)
  end

  private

  def notification_target_path(notification)
    case notification.notifiable_type
    when "Post"
      thread_path(notification.params["thread_slug"])
    else
      notifications_path
    end
  end
end
```

#### NotificationSettingsController

```ruby
# app/controllers/notification_settings_controller.rb
class NotificationSettingsController < ApplicationController
  before_action :authenticate_user!

  def edit
    @notification_setting = current_user.notification_setting
  end

  def update
    @notification_setting = current_user.notification_setting

    if @notification_setting.update(notification_setting_params)
      redirect_to edit_notification_settings_path, notice: "通知設定を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def test_discord
    @notification_setting = current_user.notification_setting

    if @notification_setting.discord_configured?
      send_test_notification(:discord)
      redirect_to edit_notification_settings_path, notice: "テスト通知を送信しました"
    else
      redirect_to edit_notification_settings_path, alert: "Discord Webhook URLを設定してください"
    end
  end

  private

  def notification_setting_params
    params.require(:notification_setting).permit(
      :notify_member_posts,
      :notify_subscription_posts,
      :notify_invitations,
      :discord_webhook_url,
      :slack_webhook_url,
      :use_discord,
      :use_slack
    )
  end

  def send_test_notification(service)
    case service
    when :discord
      HTTP.post(@notification_setting.discord_webhook_url, json: {
        embeds: [{
          title: "テスト通知",
          description: "coconikkiからのテスト通知です",
          color: 3066993,
          timestamp: Time.current.iso8601
        }]
      })
    end
  end
end
```

---

### 6. ルーティング

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # 通知
  resources :notifications, only: [:index, :show] do
    member do
      post :mark_as_read
    end
    collection do
      post :mark_all_as_read
    end
  end

  # 通知設定
  resource :notification_settings, only: [:edit, :update] do
    post :test_discord, on: :collection
    post :test_slack, on: :collection
  end
end
```

---

### 7. ビュー（簡易版）

#### 通知一覧

```slim
/ app/views/notifications/index.html.slim
h1 通知

.mb-4
  = link_to "すべて既読にする", mark_all_as_read_notifications_path, method: :post, class: "btn btn-secondary", data: { turbo_method: :post }

- if @notifications.any?
  .notifications
    - @notifications.each do |notification|
      .notification class=("unread" if notification.unread?)
        .notification-content
          = link_to notification_path(notification) do
            strong= notification.actor&.name
            span さんが投稿しました
            .text-muted.small= time_ago_in_words(notification.created_at) + "前"
            p= notification.params["post_preview"]
        - if notification.unread?
          = link_to "既読にする", mark_as_read_notification_path(notification), method: :post, class: "btn btn-sm", data: { turbo_method: :post }

  = paginate @notifications
- else
  p.text-muted 通知はありません
```

#### 通知設定

```slim
/ app/views/notification_settings/edit.html.slim
h1 通知設定

= form_with model: @notification_setting, url: notification_settings_path, method: :patch do |f|
  .section
    h2 通知タイプ

    .form-check
      = f.check_box :notify_member_posts, class: "form-check-input"
      = f.label :notify_member_posts, "参加中の文通の新規投稿", class: "form-check-label"

    .form-check
      = f.check_box :notify_subscription_posts, class: "form-check-input"
      = f.label :notify_subscription_posts, "購読中の文通の新規投稿", class: "form-check-label"

  .section
    h2 Discord通知

    .form-check
      = f.check_box :use_discord, class: "form-check-input"
      = f.label :use_discord, "Discord通知を有効化", class: "form-check-label"

    .form-group
      = f.label :discord_webhook_url, "Discord Webhook URL"
      = f.text_field :discord_webhook_url, class: "form-control", placeholder: "https://discord.com/api/webhooks/..."
      small.form-text.text-muted
        | Discordサーバーの設定 > 連携サービス > ウェブフック で作成できます

    = link_to "テスト送信", test_discord_notification_settings_path, method: :post, class: "btn btn-secondary btn-sm", data: { turbo_method: :post }

  .form-actions
    = f.submit "保存", class: "btn btn-primary"
```

#### ヘッダーの通知アイコン（レイアウト）

```slim
/ app/views/layouts/_header.html.slim
header
  nav
    / ... 他のナビゲーション ...

    - if user_signed_in?
      .notifications
        = link_to notifications_path do
          i.icon-bell
          - if current_user.unread_notifications_count > 0
            span.badge.badge-danger= current_user.unread_notifications_count
```

---

## 🧪 テスト

### モデルテスト

```ruby
# test/models/notification_test.rb
require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "should mark as read" do
    notification = notifications(:one)
    assert notification.unread?

    notification.mark_as_read!

    refute notification.unread?
    assert_not_nil notification.read_at
  end

  test "should scope unread notifications" do
    unread = Notification.unread
    assert unread.all?(&:unread?)
  end
end
```

### サービステスト

```ruby
# test/services/notification_service_test.rb
require "test_helper"

class NotificationServiceTest < ActiveSupport::TestCase
  test "should create notifications for members and subscribers" do
    post = posts(:one)
    thread = post.thread

    assert_difference "Notification.count", thread.members.count + thread.subscribers.count - 1 do
      NotificationService.notify_new_post(post)
    end
  end

  test "should not notify the post author" do
    post = posts(:one)
    author = post.user

    NotificationService.notify_new_post(post)

    assert_equal 0, author.notifications.where(notifiable: post).count
  end
end
```

### ジョブテスト

```ruby
# test/jobs/discord_notification_job_test.rb
require "test_helper"

class DiscordNotificationJobTest < ActiveJob::TestCase
  test "should send discord notification" do
    notification = notifications(:one)

    stub_request(:post, notification.user.notification_setting.discord_webhook_url)
      .to_return(status: 200)

    assert_nothing_raised do
      DiscordNotificationJob.perform_now(notification.id)
    end
  end
end
```

---

## 📊 必要なGem

### 追加するGem

```ruby
# Gemfile

# HTTP通信用
gem "http"

# ページネーション（既存かも）
gem "kaminari"
```

### インストール

```bash
bundle add http
bundle add kaminari
```

---

## 🚀 デプロイ時の注意事項

### マイグレーション実行

```bash
bin/rails db:migrate
```

### 既存ユーザーへのNotificationSetting作成

```ruby
# bin/rails runner scripts/create_notification_settings.rb

User.find_each do |user|
  user.create_notification_setting! unless user.notification_setting
end
```

### Solid Queue設定確認

Jobが正常に処理されるか確認：

```bash
bin/rails solid_queue:status
```

---

## ✅ チェックリスト

### Phase 1a完了時 🎯

- [ ] notifications/notification_settings テーブル作成
- [ ] Notification/NotificationSetting モデル作成
- [ ] User/Post モデルへの関連追加
- [ ] NotificationService 実装
- [ ] Post作成時の通知生成（published のみ）
- [ ] N+1問題の回避
- [ ] RSpec テスト作成（モデル + サービス）
- [ ] Rails console で動作確認
- [ ] コミット・プッシュ

### Phase 1b完了時

- [ ] NotificationsController 実装
- [ ] 通知一覧ページ実装
- [ ] ヘッダーに通知アイコン追加
- [ ] 既読/未読管理UI実装
- [ ] ページネーション追加
- [ ] テスト作成（コントローラー + 統合）
- [ ] ブラウザで動作確認
- [ ] PR作成・マージ

### Phase 2完了時

- [ ] DiscordNotificationJob実装
- [ ] Webhook URL設定UI実装
- [ ] テスト送信機能実装
- [ ] エラーハンドリング確認
- [ ] 本番環境でテスト
- [ ] ドキュメント更新

---

## 🔗 参考リンク

- [Discord Webhook Documentation](https://discord.com/developers/docs/resources/webhook)
- [Slack Webhook Documentation](https://api.slack.com/messaging/webhooks)
- [Rails Active Job Guide](https://guides.rubyonrails.org/active_job_basics.html)

---

**作成日**: 2026年3月15日
**最終更新**: 2026年3月21日

**更新履歴**:
- 2026-03-21: Phase 1を1aと1bに分割、技術的改善提案を反映
