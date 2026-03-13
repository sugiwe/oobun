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

本番環境のバックアップはGoogle Driveに自動保存されます。

### セットアップ

詳細は [docs/backup-setup.md](docs/backup-setup.md) を参照してください。

### バックアップの確認

```bash
# VPSにSSH接続
ssh -i ~/.ssh/coconikki_vps deploy@220.158.23.115

# バックアップ一覧を確認
rclone ls gdrive:coconikki_backups
```

### 手動バックアップ

```bash
# VPS上で実行
cd /home/deploy/oobun
sudo ./scripts/backup.sh
```

### リストア

```bash
# VPS上で実行
cd /home/deploy/oobun
sudo ./scripts/restore.sh latest
```

⚠️ 詳細な手順は [docs/backup-setup.md](docs/backup-setup.md) を必ず確認してください。

## ドキュメント

- [設計ドキュメント](docs/design.md)
- [機能仕様](docs/features.md)
- [実装方針](docs/implementation.md)
- [バックアップセットアップ](docs/backup-setup.md)

## ライセンス

Private
