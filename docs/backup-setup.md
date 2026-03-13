# バックアップセットアップガイド

coconikkiのバックアップシステムのセットアップ手順です。

## 概要

- **バックアップ先**: Google Drive
- **バックアップ内容**: PostgreSQLデータベース + Active Storage画像
- **実行頻度**: 毎日自動（cron）
- **保持期間**: 7日分
- **追加コスト**: 0円（Google Drive無料枠15GB内）

---

## 前提条件

- VPSサーバーへのSSHアクセス
- Googleアカウント（既存のものでOK）
- PostgreSQLが稼働中
- Dockerコンテナが稼働中

---

## セットアップ手順

### 1. VPSサーバーにSSH接続

```bash
ssh -i ~/.ssh/coconikki_vps deploy@220.158.23.115
```

### 2. rcloneをインストール

```bash
# rcloneをインストール
curl https://rclone.org/install.sh | sudo bash

# バージョン確認
rclone version
```

### 3. Google Drive設定

```bash
# rclone設定を開始
rclone config

# 以下の手順で設定:
# n) New remote
# name> gdrive
# Storage> drive (Google Driveを選択)
# client_id> (空Enter - デフォルトを使用)
# client_secret> (空Enter - デフォルトを使用)
# scope> 1 (Full access)
# root_folder_id> (空Enter)
# service_account_file> (空Enter)
# Edit advanced config? n
# Use auto config? n (サーバーなので手動設定)
#
# ここでブラウザ認証用のURLが表示されます
# URLをコピーして、ローカルPCのブラウザで開く
# Googleアカウントでログイン・認証
# 表示されたトークンをコピーしてVPSに貼り付け
#
# Configure this as a team drive? n
# Keep this "gdrive" remote? y
# q) Quit config
```

**ローカルPCでの認証手順（重要）**:

VPSはブラウザがないので、ローカルPCで認証します：

1. VPSに表示されたURL（`https://accounts.google.com/...`）をコピー
2. **ローカルPC**のブラウザでそのURLを開く
3. Googleアカウントでログイン
4. rcloneへのアクセスを許可
5. 表示された認証コードをコピー
6. VPSのターミナルに貼り付け

### 4. 接続テスト

```bash
# Google Driveに接続できるか確認
rclone lsd gdrive:

# テストフォルダを作成
rclone mkdir gdrive:coconikki_backups

# 確認
rclone ls gdrive:coconikki_backups
```

成功すれば空のディレクトリが表示されます。

### 5. バックアップスクリプトを配置

```bash
# プロジェクトディレクトリに移動
cd /home/deploy/oobun

# スクリプトに実行権限を付与
chmod +x scripts/backup.sh
chmod +x scripts/restore.sh
```

### 6. 手動でバックアップをテスト

```bash
# テスト実行
sudo ./scripts/backup.sh

# 実行後、Google Driveを確認
rclone ls gdrive:coconikki_backups
```

以下のファイルが表示されればOK:
- `coconikki_db_YYYYMMDD_HHMMSS.sql.gz`
- `coconikki_storage_YYYYMMDD_HHMMSS.tar.gz`

### 7. Discord通知設定（任意）

バックアップの成功・失敗をDiscordに通知できます。

#### Discord Webhookの作成

1. Discordサーバーの設定を開く
2. 「連携サービス」→「ウェブフック」を選択
3. 「新しいウェブフック」をクリック
4. 名前を設定（例: coconikki-backup）
5. 通知先チャンネルを選択
6. 「ウェブフックURLをコピー」

#### VPSで環境変数を設定

```bash
# .bashrcや.bash_profileに追加
echo 'export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"' >> ~/.bashrc
source ~/.bashrc

# 設定を確認
echo $DISCORD_WEBHOOK_URL
```

#### 通知のテスト

```bash
# テストバックアップを実行
cd /home/deploy/oobun
sudo -E ./scripts/backup.sh
```

**通知内容**:
- ✅ 成功時: 緑色のembed、実行日時、各ファイルサイズ、保存先、Google Driveリンク
- ❌ 失敗時: 赤色のembed、エラー内容

### 8. cron設定（自動実行）

```bash
# cronを編集
crontab -e

# 以下の行を追加（毎日午前3時に実行、Discord通知を有効化）
0 3 * * * export DISCORD_WEBHOOK_URL="YOUR_WEBHOOK_URL"; cd /home/deploy/oobun && sudo -E /home/deploy/oobun/scripts/backup.sh >> /home/deploy/backup.log 2>&1

# 保存して終了
# cron設定を確認
crontab -l
```

**実行時刻の選択**:
- 午前3時（日本時間）= アクセスが少ない時間帯
- サーバー時刻がUTCの場合は調整が必要（`date`コマンドで確認）

**注意**: cron内で環境変数を使うため、`sudo -E`オプションで環境変数を引き継ぎます。

---

## 9. 動作確認

バックアップが正常に動作しているか確認:

```bash
# ログを確認
tail -50 /home/deploy/backup.log

# Google Driveのファイルを確認
rclone ls gdrive:coconikki_backups

# Discord通知が届いているか確認
```

---

## リストア方法

### 最新のバックアップをリストア

```bash
cd /home/deploy/oobun
sudo ./scripts/restore.sh latest
```

### 特定の日時のバックアップをリストア

```bash
# バックアップ一覧を確認
rclone ls gdrive:coconikki_backups

# タイムスタンプを指定してリストア
sudo ./scripts/restore.sh 20260313_030000
```

⚠️ **警告**: リストアは既存のデータを上書きします！実行前に必ず確認してください。

---

## トラブルシューティング

### Q1. rclone設定でエラーが出る

**A**: 認証URLを正しくローカルPCのブラウザで開いているか確認してください。VPS上でブラウザを開こうとするとエラーになります。

### Q2. バックアップがGoogle Driveに保存されない

**A**: 以下を確認:

```bash
# rclone設定を確認
rclone config show

# 接続テスト
rclone lsd gdrive:

# 手動でアップロードテスト
echo "test" > /tmp/test.txt
rclone copy /tmp/test.txt gdrive:coconikki_backups
rclone ls gdrive:coconikki_backups
```

### Q3. PostgreSQLバックアップでエラー

**A**: PostgreSQLユーザー権限を確認:

```bash
# postgresユーザーで実行できるか確認
sudo -u postgres pg_dump coconikki_production
```

### Q4. cronが実行されない

**A**: ログを確認:

```bash
# cronログを確認
cat /home/deploy/backup.log

# cronサービスの状態を確認
systemctl status cron
```

---

## 容量管理

### 現在のバックアップサイズを確認

```bash
# Google Drive上のバックアップサイズを確認
rclone size gdrive:coconikki_backups
```

### 保持期間を変更

デフォルトは7日間ですが、容量に応じて変更可能:

```bash
# 環境変数で設定
export BACKUP_RETENTION_DAYS=3

# または、scripts/backup.sh を編集
vim scripts/backup.sh
# BACKUP_RETENTION_DAYS=3 に変更
```

---

## 将来の拡張

### 他のストレージバックエンドへの切り替え

スクリプトは他のストレージにも対応しています：

#### AWS S3に切り替え

```bash
# AWS CLI設定
aws configure

# バックアップ実行
export BACKUP_BACKEND=s3
export S3_BUCKET=coconikki-backups
sudo ./scripts/backup.sh
```

#### ローカルバックアップに切り替え

```bash
export BACKUP_BACKEND=local
sudo ./scripts/backup.sh
```

---

## 定期メンテナンス

### 月次チェックリスト

- [ ] バックアップが正常に実行されているか確認（ログ確認）
- [ ] Google Driveの容量を確認
- [ ] テストリストアを実行（開発環境で）

### バックアップログの確認

```bash
# 最新のログを確認
tail -100 /home/deploy/backup.log

# エラーがないか確認
grep ERROR /home/deploy/backup.log
```

---

## セキュリティ

- rclone設定ファイル（`~/.config/rclone/rclone.conf`）にはアクセストークンが含まれます
- このファイルは`deploy`ユーザーのみがアクセス可能です
- Google Driveへのアクセスは読み書き可能ですが、coconikkiのバックアップフォルダのみを使用します

---

## サポート

バックアップに関する問題が発生した場合：

1. ログを確認（`/home/deploy/backup.log`）
2. 手動実行でテスト（`sudo ./scripts/backup.sh`）
3. rclone接続を確認（`rclone lsd gdrive:`）
