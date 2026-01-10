#!/bin/bash

# Wavelog Docker Migration & Deploy Script
# Migrates from Apache/MariaDB to Docker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAVELOG_SRC="/var/www/wavelog"
DB_NAME="wavelog"
DB_USER="wavelog"
DB_PASS='!!123qweASD!!'

cd "$SCRIPT_DIR"

echo "=========================================="
echo "Wavelog Docker Migration"
echo "=========================================="
echo ""

# Step 1: Create directories
echo "Step 1: Creating directories..."
mkdir -p init uploads userdata backup

# Step 2: Copy existing data
echo ""
echo "Step 2: Copying existing data..."
if [ -d "$WAVELOG_SRC/uploads" ]; then
    cp -r "$WAVELOG_SRC/uploads/"* ./uploads/ 2>/dev/null || echo "  No uploads to copy"
fi
if [ -d "$WAVELOG_SRC/userdata" ]; then
    cp -r "$WAVELOG_SRC/userdata/"* ./userdata/ 2>/dev/null || echo "  No userdata to copy"
fi
if [ -d "$WAVELOG_SRC/backup" ]; then
    cp -r "$WAVELOG_SRC/backup/"* ./backup/ 2>/dev/null || echo "  No backups to copy"
fi
echo "  Data copied successfully"

# Step 3: Export database
echo ""
echo "Step 3: Exporting database..."
if [ -f "./init/wavelog_backup.sql" ]; then
    echo "  Database backup already exists, skipping export"
else
    echo "  Attempting database export..."
    if mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > ./init/wavelog_backup.sql 2>/dev/null; then
        echo "  Database exported successfully"
    else
        echo ""
        echo "  ERROR: Could not export database automatically."
        echo "  Please run manually with root/sudo access:"
        echo ""
        echo "    sudo mysqldump wavelog > $SCRIPT_DIR/init/wavelog_backup.sql"
        echo ""
        echo "  Then re-run this script."
        exit 1
    fi
fi

# Step 4: Stop Apache
echo ""
echo "Step 4: Stopping Apache..."
if systemctl is-active --quiet apache2; then
    sudo systemctl stop apache2
    sudo systemctl disable apache2
    echo "  Apache stopped and disabled"
else
    echo "  Apache already stopped"
fi

# Step 5: Build and start containers
echo ""
echo "Step 5: Starting Docker containers..."
docker compose pull
docker compose up -d

# Step 6: Wait for health checks
echo ""
echo "Step 6: Waiting for containers to become healthy..."
echo "  Waiting for database..."
for i in {1..60}; do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' wavelog-db 2>/dev/null || echo "starting")
    if [ "$STATUS" = "healthy" ]; then
        echo "  Database is healthy!"
        break
    fi
    echo "    Database status: $STATUS (attempt $i/60)"
    sleep 2
done

echo "  Waiting for Wavelog..."
for i in {1..60}; do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' wavelog 2>/dev/null || echo "starting")
    if [ "$STATUS" = "healthy" ]; then
        echo "  Wavelog is healthy!"
        break
    elif [ "$STATUS" = "unhealthy" ]; then
        echo "  Wavelog is unhealthy. Checking logs..."
        docker logs wavelog --tail 20
        break
    fi
    echo "    Wavelog status: $STATUS (attempt $i/60)"
    sleep 2
done

# Show final status
echo ""
echo "=========================================="
echo "Deployment complete!"
echo "=========================================="
docker ps --filter "name=wavelog" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "Wavelog running at: http://localhost:80"
echo "External access via: https://wavelog.oeradio.at"
echo ""
echo "IMPORTANT: On first access, you need to configure the database connection:"
echo "  - Database Host: wavelog-db"
echo "  - Database Name: wavelog"
echo "  - Database User: wavelog"
echo "  - Database Password: (as configured)"
echo ""
