#!/bin/bash

# Deploy wavelog to Synology NAS
# Usage: ./deploy-production.sh
#
# Note: This deployment pulls the latest wavelog image and restarts the container.
# Database is preserved in the wavelog-dbdata volume.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "$SCRIPT_DIR/.env.production" ]; then
  export $(grep -v '^#' "$SCRIPT_DIR/.env.production" | xargs)
else
  echo "ERROR: .env.production not found"
  echo "Copy .env.production.example to .env.production and configure it"
  exit 1
fi

echo "=========================================="
echo "Deploying Wavelog to Synology"
echo "=========================================="

# Pull latest changes
echo ""
echo "[1/4] Pulling latest changes from GitHub..."
ssh $SYNOLOGY_HOST "cd $REMOTE_DIR && git pull"

# Pull latest wavelog image
echo ""
echo "[2/4] Pulling latest wavelog image..."
ssh $SYNOLOGY_HOST "/usr/local/bin/docker pull ghcr.io/wavelog/wavelog:latest"

# Restart container
echo ""
echo "[3/4] Restarting container..."
ssh $SYNOLOGY_HOST "/usr/local/bin/docker stop $CONTAINER_NAME 2>/dev/null || true"
ssh $SYNOLOGY_HOST "/usr/local/bin/docker rm $CONTAINER_NAME 2>/dev/null || true"

ssh $SYNOLOGY_HOST "/usr/local/bin/docker run -d \
  --name $CONTAINER_NAME \
  --network wavelog-network \
  -e CI_ENV=docker \
  -v /volume1/docker/wavelog/uploads:/var/www/html/uploads \
  -v /volume1/docker/wavelog/userdata:/var/www/html/userdata \
  -v /volume1/docker/wavelog/backup:/var/www/html/backup \
  -v wavelog-config:/var/www/html/application/config/docker \
  -p $CONTAINER_PORT \
  --restart unless-stopped \
  ghcr.io/wavelog/wavelog:latest"

# Verify
echo ""
echo "[4/4] Verifying deployment..."
sleep 5
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$SITE_URL")

if [ "$HTTP_CODE" = "200" ]; then
  echo ""
  echo "=========================================="
  echo "Deployment successful!"
  echo "$SITE_URL is responding (HTTP $HTTP_CODE)"
  echo "=========================================="
else
  echo ""
  echo "WARNING: Site returned HTTP $HTTP_CODE"
  echo "Check logs: ssh $SYNOLOGY_HOST '/usr/local/bin/docker logs $CONTAINER_NAME'"
fi
