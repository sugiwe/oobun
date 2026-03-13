# coconikki (oobun)

coconikkiは、誰でも読める公開交換日記サービスです。

## 技術スタック

- Ruby on Rails 8.1
- PostgreSQL
- Docker + Kamal (デプロイ)
- Hotwire (Turbo + Stimulus)
- Tailwind CSS

## 開発環境セットアップ

```bash
# 依存関係のインストール
bin/setup

# 開発サーバー起動
bin/dev

# テスト実行
bin/rails test
```

## デプロイ

Kamalを使用してVPSにデプロイします。

```bash
# デプロイ
bin/kamal deploy

# コンソールにアクセス
bin/kamal console

# ログ確認
bin/kamal logs
```

## バックアップ

本番環境のバックアップはGoogle Driveに自動保存されます（毎日午前3時、Discord通知あり）。

### 運用ドキュメント

- [バックアップ運用マニュアル](docs/backup/operations.md) - 日常的な運用方法
- [復元ガイド](docs/backup/restore-guide.md) - バックアップからの復元手順
- [セットアップ手順](docs/backup/setup.md) - 初回セットアップ方法

### クイックリファレンス

```bash
# バックアップ確認
rclone ls gdrive:coconikki_backups

# 手動バックアップ
cd ~/backup-scripts
sudo -E ./backup.sh

# 復元（最新）
cd ~/backup-scripts
sudo ./restore.sh latest
```

## ドキュメント

- [設計ドキュメント](docs/design.md)
- [機能仕様](docs/features.md)
- [実装方針](docs/implementation.md)
- [バックアップ運用](docs/backup/) - バックアップシステムのドキュメント

## ライセンス

Private
