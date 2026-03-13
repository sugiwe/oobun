#!/bin/bash
set -e

# coconikkiバックアップスクリプト
# Google Driveへの自動バックアップ
#
# 使い方:
#   ./scripts/backup.sh
#
# 必要な環境変数:
#   BACKUP_BACKEND (デフォルト: gdrive)
#   BACKUP_RETENTION_DAYS (デフォルト: 7)

# 設定
BACKUP_BACKEND=${BACKUP_BACKEND:-gdrive}
BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}
BACKUP_DIR="/tmp/coconikki_backup_$(date +%Y%m%d_%H%M%S)"
DATE=$(date +%Y%m%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

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
  if [ -d "$BACKUP_DIR" ]; then
    log "クリーンアップ中..."
    rm -rf "$BACKUP_DIR"
  fi
}
trap cleanup EXIT

log "=== coconikkiバックアップ開始 ==="
log "バックアップ先: $BACKUP_BACKEND"
log "保持期間: ${BACKUP_RETENTION_DAYS}日"

# バックアップディレクトリ作成
mkdir -p "$BACKUP_DIR"

# ========================================
# 1. PostgreSQLバックアップ
# ========================================
log "PostgreSQLをバックアップ中..."

DB_BACKUP_FILE="$BACKUP_DIR/coconikki_db_${TIMESTAMP}.sql.gz"

if pg_dump -U postgres coconikki_production | gzip > "$DB_BACKUP_FILE"; then
  DB_SIZE=$(du -h "$DB_BACKUP_FILE" | cut -f1)
  log "PostgreSQLバックアップ完了: ${DB_SIZE}"
else
  error "PostgreSQLバックアップに失敗しました"
fi

# ========================================
# 2. Active Storageバックアップ
# ========================================
log "Active Storageをバックアップ中..."

STORAGE_BACKUP_FILE="$BACKUP_DIR/coconikki_storage_${TIMESTAMP}.tar.gz"
STORAGE_PATH="/var/lib/docker/volumes/coconikki_storage/_data"

if [ ! -d "$STORAGE_PATH" ]; then
  error "Active Storageディレクトリが見つかりません: $STORAGE_PATH"
fi

if sudo tar czf "$STORAGE_BACKUP_FILE" -C "$STORAGE_PATH" .; then
  STORAGE_SIZE=$(du -h "$STORAGE_BACKUP_FILE" | cut -f1)
  log "Active Storageバックアップ完了: ${STORAGE_SIZE}"
else
  error "Active Storageバックアップに失敗しました"
fi

# ========================================
# 3. バックアップをアップロード
# ========================================
log "バックアップをアップロード中..."

case $BACKUP_BACKEND in
  "gdrive")
    if ! command -v rclone &> /dev/null; then
      error "rcloneがインストールされていません"
    fi

    REMOTE_PATH="gdrive:coconikki_backups"

    if rclone copy "$BACKUP_DIR" "$REMOTE_PATH" --verbose; then
      log "Google Driveへのアップロード完了"

      # 古いバックアップを削除
      log "${BACKUP_RETENTION_DAYS}日より古いバックアップを削除中..."
      rclone delete "$REMOTE_PATH" --min-age "${BACKUP_RETENTION_DAYS}d" --verbose

      # バックアップ一覧を表示
      log "現在のバックアップ一覧:"
      rclone ls "$REMOTE_PATH"
    else
      error "Google Driveへのアップロードに失敗しました"
    fi
    ;;

  "local")
    LOCAL_BACKUP_DIR="/home/deploy/backups"
    mkdir -p "$LOCAL_BACKUP_DIR"

    if cp -r "$BACKUP_DIR"/* "$LOCAL_BACKUP_DIR/"; then
      log "ローカルバックアップ完了: $LOCAL_BACKUP_DIR"

      # 古いバックアップを削除
      find "$LOCAL_BACKUP_DIR" -name "coconikki_*" -mtime +${BACKUP_RETENTION_DAYS} -delete
    else
      error "ローカルバックアップに失敗しました"
    fi
    ;;

  "s3")
    if ! command -v aws &> /dev/null; then
      error "AWS CLIがインストールされていません"
    fi

    S3_BUCKET=${S3_BUCKET:-coconikki-backups}

    if aws s3 sync "$BACKUP_DIR" "s3://${S3_BUCKET}/"; then
      log "AWS S3へのアップロード完了"
    else
      error "AWS S3へのアップロードに失敗しました"
    fi
    ;;

  *)
    error "不明なバックアップバックエンド: $BACKUP_BACKEND"
    ;;
esac

log "=== バックアップ完了 ==="
log "合計サイズ: $(du -sh "$BACKUP_DIR" | cut -f1)"
