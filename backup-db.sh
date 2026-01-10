#!/bin/bash

# Wavelog Database Backup Script
# Creates daily backups with configurable retention

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/backup}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
CONTAINER_NAME="${CONTAINER_NAME:-wavelog-db}"
DB_NAME="${DB_NAME:-wavelog}"
DB_USER="${DB_USER:-wavelog}"
DB_PASS="${DB_PASS:-WavelogPass123}"

# Timestamp for backup file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE=$(date +%Y-%m-%d)
BACKUP_FILE="wavelog_${TIMESTAMP}.sql"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# Create backup directory if it doesn't exist
if [ ! -d "$BACKUP_DIR" ]; then
    log "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
fi

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    error "Container $CONTAINER_NAME is not running"
    exit 1
fi

# Check container health
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
if [ "$HEALTH" != "healthy" ]; then
    error "Container $CONTAINER_NAME is not healthy (status: $HEALTH)"
    exit 1
fi

# Perform backup
log "Starting backup of database '$DB_NAME'..."
log "Backup file: $BACKUP_PATH"

if docker exec "$CONTAINER_NAME" mariadb-dump \
    -u "$DB_USER" \
    -p"$DB_PASS" \
    --single-transaction \
    --routines \
    --triggers \
    "$DB_NAME" > "$BACKUP_PATH" 2>/dev/null; then

    # Get backup size
    BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
    log "Backup completed successfully (size: $BACKUP_SIZE)"

    # Compress backup
    log "Compressing backup..."
    gzip "$BACKUP_PATH"
    COMPRESSED_SIZE=$(du -h "${BACKUP_PATH}.gz" | cut -f1)
    log "Compressed backup: ${BACKUP_PATH}.gz (size: $COMPRESSED_SIZE)"
else
    error "Backup failed!"
    rm -f "$BACKUP_PATH"
    exit 1
fi

# Clean up old backups
log "Cleaning up backups older than $RETENTION_DAYS days..."
DELETED_COUNT=$(find "$BACKUP_DIR" -name "wavelog_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete -print | wc -l)
log "Deleted $DELETED_COUNT old backup(s)"

# Show current backups
log "Current backups in $BACKUP_DIR:"
ls -lh "$BACKUP_DIR"/wavelog_*.sql.gz 2>/dev/null | tail -5 || log "  No backups found"

# Summary
TOTAL_BACKUPS=$(ls -1 "$BACKUP_DIR"/wavelog_*.sql.gz 2>/dev/null | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
log "Total backups: $TOTAL_BACKUPS, Total size: $TOTAL_SIZE"
log "Backup completed successfully!"
