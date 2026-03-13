#!/bin/bash
set -e -o pipefail

# coconikkiリストアスクリプト
# Google Driveからのバックアップ復元
#
# 使い方:
#   ./scripts/restore.sh [バックアップ日時]
#
# 例:
#   ./scripts/restore.sh 20260313_020000
#   ./scripts/restore.sh latest  # 最新のバックアップを使用
#
# 必要な環境変数:
#   BACKUP_BACKEND (デフォルト: gdrive)

# 設定
BACKUP_BACKEND=${BACKUP_BACKEND:-gdrive}
RESTORE_DIR=$(mktemp -d /tmp/coconikki_restore.XXXXXX)
BACKUP_TIMESTAMP=${1:-latest}

# ログ出力
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# エラーハンドリング
error() {
  log "ERROR: $*"
  exit 1
}

# クリーンアップ
cleanup() {
  if [ -d "$RESTORE_DIR" ]; then
    log "クリーンアップ中..."
    rm -rf "$RESTORE_DIR"
  fi
}
trap cleanup EXIT

# 確認プロンプト
confirm() {
  read -p "$1 [y/N]: " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "キャンセルしました"
    exit 0
  fi
}

log "=== coconikkiリストア開始 ==="
log "バックアップ元: $BACKUP_BACKEND"
log "タイムスタンプ: $BACKUP_TIMESTAMP"

# 警告
echo ""
echo "⚠️  警告: このスクリプトは既存のデータを上書きします！"
echo ""
confirm "本当にリストアを実行しますか？"

# リストアディレクトリ作成
mkdir -p "$RESTORE_DIR"

# ========================================
# 1. バックアップをダウンロード
# ========================================
log "バックアップをダウンロード中..."

case $BACKUP_BACKEND in
  "gdrive")
    if ! command -v rclone &> /dev/null; then
      error "rcloneがインストールされていません"
    fi

    REMOTE_PATH="gdrive:coconikki_backups"

    # 利用可能なバックアップを表示
    log "利用可能なバックアップ:"
    rclone ls "$REMOTE_PATH"

    # ダウンロード
    if [ "$BACKUP_TIMESTAMP" = "latest" ]; then
      log "最新のバックアップを特定中..."
      LATEST_TIMESTAMP=$(rclone lsf "$REMOTE_PATH" | grep 'coconikki_db_' | sed -E 's/.*coconikki_db_([0-9]{8}_[0-9]{6})\.sql\.gz/\1/' | sort -r | head -n 1)
      if [ -z "$LATEST_TIMESTAMP" ]; then
        error "最新のバックアップが見つかりません"
      fi
      log "最新のタイムスタンプ: $LATEST_TIMESTAMP"
      BACKUP_TIMESTAMP=$LATEST_TIMESTAMP
    fi

    log "指定されたバックアップをダウンロード中..."
    rclone copy "$REMOTE_PATH" "$RESTORE_DIR" \
      --include "*${BACKUP_TIMESTAMP}*" --verbose

    if [ ! "$(ls -A $RESTORE_DIR)" ]; then
      error "バックアップファイルが見つかりません"
    fi
    ;;

  "local")
    LOCAL_BACKUP_DIR="/home/deploy/backups"

    if [ ! -d "$LOCAL_BACKUP_DIR" ]; then
      error "ローカルバックアップディレクトリが見つかりません: $LOCAL_BACKUP_DIR"
    fi

    if [ "$BACKUP_TIMESTAMP" = "latest" ]; then
      # 最新のバックアップを取得
      cp -r "$LOCAL_BACKUP_DIR"/* "$RESTORE_DIR/"
    else
      cp "$LOCAL_BACKUP_DIR"/*${BACKUP_TIMESTAMP}* "$RESTORE_DIR/"
    fi
    ;;

  *)
    error "不明なバックアップバックエンド: $BACKUP_BACKEND"
    ;;
esac

# ========================================
# 2. PostgreSQLをリストア
# ========================================
log "PostgreSQLをリストア中..."

DB_BACKUP=$(ls "$RESTORE_DIR"/coconikki_db_*.sql.gz | sort -r | head -1)

if [ -z "$DB_BACKUP" ]; then
  error "PostgreSQLバックアップファイルが見つかりません"
fi

log "使用するバックアップ: $(basename $DB_BACKUP)"

# データベースを一旦削除して再作成
log "データベースへのアクティブな接続を切断中..."
psql -U postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = 'coconikki_production' AND pid <> pg_backend_pid();"

log "既存のデータベースを削除中..."
psql -U postgres -c "DROP DATABASE IF EXISTS coconikki_production;"
psql -U postgres -c "CREATE DATABASE coconikki_production;"

# リストア実行
if gunzip -c "$DB_BACKUP" | psql -U postgres coconikki_production; then
  log "PostgreSQLリストア完了"
else
  error "PostgreSQLリストアに失敗しました"
fi

# ========================================
# 3. Active Storageをリストア
# ========================================
log "Active Storageをリストア中..."

STORAGE_BACKUP=$(ls "$RESTORE_DIR"/coconikki_storage_*.tar.gz | sort -r | head -1)

if [ -z "$STORAGE_BACKUP" ]; then
  error "Active Storageバックアップファイルが見つかりません"
fi

log "使用するバックアップ: $(basename $STORAGE_BACKUP)"

STORAGE_PATH="/var/lib/docker/volumes/coconikki_storage/_data"

# 既存のファイルをバックアップ（念のため）
if [ -d "$STORAGE_PATH" ]; then
  BACKUP_OLD_STORAGE="/tmp/old_storage_$(date +%Y%m%d_%H%M%S)"
  log "既存のストレージを一時バックアップ: $BACKUP_OLD_STORAGE"
  sudo mv "$STORAGE_PATH" "$BACKUP_OLD_STORAGE"
fi

# ストレージディレクトリを作成
sudo mkdir -p "$STORAGE_PATH"

# リストア実行
if sudo tar xzf "$STORAGE_BACKUP" -C "$STORAGE_PATH"; then
  log "Active Storageリストア完了"

  # 一時バックアップを削除
  if [ -d "$BACKUP_OLD_STORAGE" ]; then
    sudo rm -rf "$BACKUP_OLD_STORAGE"
  fi
else
  error "Active Storageリストアに失敗しました"
fi

# ========================================
# 4. アプリケーションを再起動
# ========================================
log "アプリケーションを再起動中..."

cd /home/deploy/oobun

if bin/kamal app restart; then
  log "アプリケーション再起動完了"
else
  log "WARNING: アプリケーションの再起動に失敗しました（手動で確認してください）"
fi

log "=== リストア完了 ==="
log "復元したバックアップ:"
log "  - Database: $(basename $DB_BACKUP)"
log "  - Storage: $(basename $STORAGE_BACKUP)"
