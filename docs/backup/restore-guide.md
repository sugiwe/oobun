# バックアップ復元ガイド

coconikkiのバックアップから本番環境を復元する手順です。

---

## ⚠️ 重要な注意事項

- **復元は既存データを上書きします**
- **バックアップ以降のデータは失われます**
- **復元前に必ず現状を確認してください**
- **不安な場合は、まず手動でバックアップを取ってから復元してください**

---

## 📦 バックアップファイルの中身

Google Driveに保存されている2つのファイルについて理解しましょう。

### 1. データベースバックアップ

**ファイル名**: `coconikki_db_YYYYMMDD_HHMMSS.sql.gz`

- **形式**: gzip圧縮されたSQLダンプ
- **内容**:
  - 全ユーザー情報
  - 全スレッド
  - 全投稿
  - フォロー/サブスクリプション関係
  - その他全テーブルのデータ

**中身を確認する方法**（ローカルPCで）:
```bash
# ダウンロードしたファイルを解凍
gunzip coconikki_db_20260313_030000.sql.gz

# テキストエディタで開く
less coconikki_db_20260313_030000.sql
```

解凍すると、以下のようなSQL文が含まれています：
```sql
CREATE TABLE users (...);
INSERT INTO users VALUES (1, 'user@example.com', ...);
INSERT INTO users VALUES (2, 'another@example.com', ...);
CREATE TABLE threads (...);
INSERT INTO threads VALUES (1, 'my-first-thread', ...);
...
```

### 2. 画像ストレージバックアップ

**ファイル名**: `coconikki_storage_YYYYMMDD_HHMMSS.tar.gz`

- **形式**: tar + gzip圧縮されたアーカイブ
- **内容**: ユーザーがアップロードした全ての画像ファイル

**中身を確認する方法**（ローカルPCで）:
```bash
# ダウンロードしたファイルを解凍
tar xzf coconikki_storage_20260313_030000.tar.gz

# 解凍されたフォルダを開く
# Active Storageの保存形式（ハッシュ化されたファイル名）で画像が入っている
```

---

## 🔄 復元の仕組み

### 自動復元フロー

`restore.sh` スクリプトが以下を自動的に実行します：

```
1. Google Driveからバックアップをダウンロード
   ↓
2. データベースを削除・再作成
   ↓
3. バックアップからデータを復元
   ↓
4. 画像ストレージを復元
   ↓
5. アプリケーションを再起動
   ↓
6. 完了！
```

### 復元される内容

✅ **復元されるもの**
- バックアップ時点までの全データ
- 全ユーザーアカウント
- 全スレッドと投稿
- 全アップロード画像
- フォロー/サブスクリプション関係

❌ **失われるもの**
- **バックアップ以降のデータ**
  - 例: 午前3時にバックアップ、午後5時に障害発生
  - → 午前3時〜午後5時の投稿は消失

### タイムライン例

```
3:00 AM  自動バックアップ実行
         ├─ ユーザー数: 100人
         ├─ スレッド数: 50個
         └─ 投稿数: 500件
         📸 この時点のスナップショットを保存

10:00 AM ユーザーAが新規投稿
         └─ 投稿ID: 501

12:00 PM ユーザーBが新規登録
         └─ ユーザーID: 101

5:00 PM  💥 データベース障害発生！

6:00 PM  restore.sh 実行
         └─ 3:00 AMの状態に復元
         ├─ ユーザー数: 100人（Bは消失）
         ├─ スレッド数: 50個
         └─ 投稿数: 500件（Aの投稿は消失）
```

**最大データ損失**: 24時間分（毎日3時バックアップのため）

---

## 🚀 復元手順

### 事前確認

復元を実行する前に、以下を確認してください：

1. **障害の状況を把握**
   - 何が失われたのか？
   - いつから問題が起きているのか？

2. **復元が本当に必要か確認**
   - データベース接続エラー → アプリ再起動で直る可能性あり
   - 一部データの不整合 → 個別修正できる可能性あり
   - 完全なデータ消失 → 復元が必要

3. **どの時点に戻すか決定**
   ```bash
   # 利用可能なバックアップを確認
   rclone ls gdrive:coconikki_backups
   ```

### 復元実行

#### パターン1: 最新のバックアップから復元（推奨）

```bash
# VPSにSSH接続
ssh -i ~/.ssh/coconikki_vps deploy@220.158.23.115

# バックアップスクリプトのディレクトリに移動
cd ~/backup-scripts

# 復元実行
sudo ./restore.sh latest
```

**実行後の流れ**:
1. ⚠️ 警告メッセージが表示される
   ```
   ⚠️  警告: このスクリプトは既存のデータを上書きします！

   本当にリストアを実行しますか？ [y/N]:
   ```

2. `y` を入力してEnter

3. 復元処理が開始される（5〜10分程度）
   - Google Driveからダウンロード
   - データベース復元
   - ストレージ復元
   - アプリ再起動

4. 完了メッセージが表示される
   ```
   === リストア完了 ===
   復元したバックアップ:
     - Database: coconikki_db_20260313_030000.sql.gz
     - Storage: coconikki_storage_20260313_030000.tar.gz
   ```

#### パターン2: 特定の日時のバックアップから復元

```bash
# 利用可能なバックアップを確認
rclone ls gdrive:coconikki_backups

# 出力例:
# 1234567  coconikki_db_20260310_030000.sql.gz
# 8901234  coconikki_storage_20260310_030000.tar.gz
# 1234567  coconikki_db_20260311_030000.sql.gz
# 8901234  coconikki_storage_20260311_030000.tar.gz
# 1234567  coconikki_db_20260313_030000.sql.gz
# 8901234  coconikki_storage_20260313_030000.tar.gz

# タイムスタンプを指定してリストア（3日前の場合）
sudo ./restore.sh 20260310_030000
```

### 復元後の確認

1. **アプリケーションの動作確認**
   ```bash
   # アプリのログを確認
   cd /home/deploy/oobun
   bin/kamal app logs
   ```

2. **Webサイトにアクセス**
   - https://coconikki.com を開く
   - ログイン可能か確認
   - 投稿が表示されるか確認
   - 画像が表示されるか確認

3. **データの整合性確認**
   - 最新の投稿日時を確認（バックアップ時点になっているか）
   - ユーザー数を確認
   - スレッド数を確認

---

## 🛠️ トラブルシューティング

### 復元が途中で失敗する

#### エラー: Google Driveに接続できない

```bash
# rclone接続を確認
rclone lsd gdrive:

# エラーが出る場合は再認証
rclone config reconnect gdrive:
```

#### エラー: PostgreSQLに接続できない

```bash
# PostgreSQLの状態を確認
sudo systemctl status postgresql

# 起動していない場合は起動
sudo systemctl start postgresql
```

#### エラー: ストレージディレクトリが見つからない

```bash
# Dockerボリュームを確認
docker volume ls | grep coconikki

# ボリュームが存在しない場合は作成
docker volume create coconikki_storage
```

### 復元後にアプリが起動しない

```bash
# アプリのログを確認
cd /home/deploy/oobun
bin/kamal app logs

# 手動で再起動
bin/kamal app restart
```

### 復元したデータが古すぎる

より新しいバックアップから再度復元してください：

```bash
# バックアップ一覧を確認
rclone ls gdrive:coconikki_backups

# 新しいタイムスタンプで再実行
sudo ./restore.sh 20260313_030000
```

---

## 🔒 緊急時の手順

### シナリオ1: データベースが完全に破損

```bash
# 1. 最新のバックアップから復元
cd ~/backup-scripts
sudo ./restore.sh latest

# 2. アプリケーション再起動
cd /home/deploy/oobun
bin/kamal app restart

# 3. 動作確認
bin/kamal app logs
```

### シナリオ2: VPS全体が故障・交換

1. **新しいVPSをセットアップ**
   - Railsアプリケーションをデプロイ
   - PostgreSQLをインストール
   - Dockerをセットアップ

2. **バックアップシステムをセットアップ**
   - [backup-setup.md](backup-setup.md) を参照
   - rcloneをインストール
   - Google Drive認証を設定

3. **バックアップから復元**
   ```bash
   cd ~/backup-scripts
   sudo ./restore.sh latest
   ```

---

## 📝 復元のベストプラクティス

### 定期的なリストアテスト（推奨）

本番環境ではなく、**開発環境やテスト環境**で定期的にリストアをテストしてください：

```bash
# 開発環境で実行
export BACKUP_BACKEND=gdrive
cd ~/backup-scripts
sudo ./restore.sh latest
```

これにより：
- 復元手順が正しく動作することを確認
- いざという時に慌てない
- バックアップの健全性を確認

### 復元前の緊急バックアップ

もし時間に余裕があれば、復元前に現状のバックアップを取ってください：

```bash
# 緊急バックアップ（手動実行）
cd ~/backup-scripts
sudo -E ./backup.sh

# Google Driveに保存されたことを確認
rclone ls gdrive:coconikki_backups
```

これにより、復元後に「やっぱり復元前の状態に戻したい」となった場合でも対応可能です。

---

## 📞 サポート

復元に関する問題が発生した場合：

1. エラーメッセージをスクリーンショットまたはコピー
2. 実行したコマンドを記録
3. 以下のログを確認・保存：
   ```bash
   # 復元ログ（存在する場合）
   cat ~/restore.log

   # アプリケーションログ
   cd /home/deploy/oobun
   bin/kamal app logs

   # PostgreSQLログ
   sudo tail -100 /var/log/postgresql/postgresql-*.log
   ```

問題が解決しない場合は、上記の情報を持って相談してください。

---

## 関連ドキュメント

- [バックアップ運用マニュアル](operations.md) - 日常的なバックアップ運用
- [バックアップセットアップ手順](setup.md) - 初回セットアップ方法
