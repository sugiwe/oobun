# バックアップシステム

coconikkiの本番環境データを自動的にバックアップするシステムです。

---

## 📋 概要

### バックアップ内容
- PostgreSQLデータベース（全データ）
- Active Storage画像（アップロード画像）

### バックアップ先
- Google Drive（coconikki_backups フォルダ）
- 無料枠15GB内で運用（現在の使用量: 数MB程度）

### 自動実行
- 毎日午前3時に自動バックアップ
- Discord通知あり（成功/失敗、サイズ情報）

### 保持期間
- 7日分を保持（古いバックアップは自動削除）

---

## ✅ セットアップ済み項目

以下の作業は完了しています：

- [x] rcloneインストール（v1.73.2）
- [x] Google Drive OAuth認証設定
- [x] バックアップスクリプト配置（`~/backup-scripts/`）
- [x] Discord Webhook設定
- [x] 手動バックアップテスト実行（成功確認済み）
- [x] cron設定（毎日午前3時自動実行）

---

## 🔄 日常運用

### 自動バックアップ

毎日午前3時に自動実行されます。特に操作は不要です。

Discord通知で結果を確認してください：
- ✅ 緑色のembed = 成功
- ❌ 赤色のembed = 失敗（要確認）

### 月次確認（推奨）

月に1回程度、以下を確認することを推奨します：

```bash
# VPSにSSH接続
ssh -i ~/.ssh/coconikki_vps deploy@220.158.23.115

# バックアップログを確認
tail -50 ~/backup.log

# Google Driveの内容を確認
rclone ls gdrive:coconikki_backups

# 容量を確認
rclone size gdrive:coconikki_backups
```

---

## 🔧 手動操作

### 手動バックアップ

緊急時や確認のため、手動でバックアップを実行できます：

```bash
cd ~/backup-scripts
sudo -E ./backup.sh
```

実行後、Discordに通知が届き、Google Driveにファイルが保存されます。

### リストア（復元）

⚠️ **警告**: リストアは既存データを上書きします！

#### 最新のバックアップから復元

```bash
cd ~/backup-scripts
sudo ./restore.sh latest
```

#### 特定の日時のバックアップから復元

```bash
# バックアップ一覧を確認
rclone ls gdrive:coconikki_backups

# タイムスタンプを指定してリストア
sudo ./restore.sh 20260313_030000
```

リストア後、アプリケーションは自動的に再起動されます。

---

## 🛠️ トラブルシューティング

### バックアップが失敗する

1. **Discordで失敗通知を確認**
   - エラー内容が表示されます

2. **ログを確認**
   ```bash
   tail -100 ~/backup.log
   ```

3. **手動実行でテスト**
   ```bash
   cd ~/backup-scripts
   sudo -E ./backup.sh
   ```

### Discord通知が届かない

1. **環境変数を確認**
   ```bash
   echo $DISCORD_WEBHOOK_URL
   ```

   空の場合は再設定：
   ```bash
   echo 'export DISCORD_WEBHOOK_URL="YOUR_WEBHOOK_URL"' >> ~/.bashrc
   source ~/.bashrc
   ```

2. **cron設定を確認**
   ```bash
   crontab -l
   ```

### Google Driveに接続できない

```bash
# 接続テスト
rclone lsd gdrive:

# 再認証が必要な場合
rclone config reconnect gdrive:
```

---

## 📁 ファイル構成

### VPS上のファイル

```
~/backup-scripts/
├── backup.sh        # バックアップスクリプト
└── restore.sh       # リストアスクリプト

~/backup.log         # バックアップ実行ログ

~/.config/rclone/
└── rclone.conf      # rclone設定（認証情報含む）

~/.bashrc            # DISCORD_WEBHOOK_URL環境変数
```

### Google Drive

```
coconikki_backups/
├── coconikki_db_20260313_030000.sql.gz
├── coconikki_storage_20260313_030000.tar.gz
├── coconikki_db_20260314_030000.sql.gz
├── coconikki_storage_20260314_030000.tar.gz
└── ... (7日分)
```

---

## 🔐 セキュリティ

- rclone設定ファイル（`~/.config/rclone/rclone.conf`）にはGoogle OAuth認証トークンが含まれます
- このファイルは`deploy`ユーザーのみがアクセス可能です
- Discord Webhook URLは環境変数として保存されています
- バックアップファイルはGoogle Driveの個人アカウントに保存されます

---

## 💡 将来の拡張

### 他のストレージへの切り替え

スクリプトは複数のバックエンドに対応しています：

#### AWS S3に切り替え
```bash
export BACKUP_BACKEND=s3
export S3_BUCKET=coconikki-backups
sudo -E ./backup.sh
```

#### ローカルバックアップに切り替え
```bash
export BACKUP_BACKEND=local
sudo -E ./backup.sh
```

### 保持期間の変更

```bash
# 3日に変更する場合
export BACKUP_RETENTION_DAYS=3
sudo -E ./backup.sh
```

または `backup.sh` を直接編集して `BACKUP_RETENTION_DAYS=3` に変更。

---

## 📚 関連ドキュメント

- [詳細セットアップ手順](setup.md) - 初回セットアップの詳細手順
- [復元ガイド](restore-guide.md) - バックアップからの復元方法
- [README](../../README.md) - プロジェクト全体のドキュメント

---

## 📞 サポート

バックアップに関する問題が発生した場合：

1. Discord通知のエラー内容を確認
2. `~/backup.log` でログを確認
3. 手動実行でテスト（`sudo -E ./backup.sh`）
4. rclone接続を確認（`rclone lsd gdrive:`）

それでも解決しない場合は、ログとエラーメッセージを保存して相談してください。
