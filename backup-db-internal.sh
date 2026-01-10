#!/bin/bash

# Wavelog Database Backup Script (runs inside container)
# Called by cron or manually

set -e

BACKUP_DIR="/backup"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
DB_NAME="wavelog"
DB_USER="wavelog"
DB_PASS="WavelogPass123"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="wavelog_${TIMESTAMP}.sql"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Create backup directory if needed
mkdir -p "$BACKUP_DIR"

log "Starting backup of database '$DB_NAME'..."

# Perform backup (connect to wavelog-db container via network)
if mariadb-dump \
    -h wavelog-db \
    -u "$DB_USER" \
    -p"$DB_PASS" \
    --single-transaction \
    --routines \
    --triggers \
    "$DB_NAME" > "$BACKUP_PATH"; then

    BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
    log "Backup completed (size: $BACKUP_SIZE)"

    # Compress
    gzip "$BACKUP_PATH"
    COMPRESSED_SIZE=$(du -h "${BACKUP_PATH}.gz" | cut -f1)
    log "Compressed: ${BACKUP_PATH}.gz (size: $COMPRESSED_SIZE)"
else
    log "ERROR: Backup failed!"
    rm -f "$BACKUP_PATH"
    exit 1
fi

# Clean up old backups
DELETED=$(find "$BACKUP_DIR" -name "wavelog_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete -print | wc -l)
log "Cleaned up $DELETED old backup(s)"

# Summary
TOTAL=$(ls -1 "$BACKUP_DIR"/wavelog_*.sql.gz 2>/dev/null | wc -l)
log "Total backups: $TOTAL"
log "Backup completed successfully!"
