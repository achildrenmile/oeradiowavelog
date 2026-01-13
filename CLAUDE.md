# Wavelog Docker - Claude Context

## Project Overview

Docker deployment for Wavelog amateur radio logging software, migrated from Apache/MariaDB to Docker containers.

- **Owner:** OE8YML
- **URL:** https://wavelog.oeradio.at
- **Repository:** https://github.com/achildrenmile/oeradiowavelog
- **Local Path:** /home/oe8yml/oeradiowavelog

## Deployment

### Production (Synology NAS)

```bash
# Deploy/update wavelog
./deploy-production.sh
```

**Requirements:**
- Copy `.env.production.example` to `.env.production` and configure
- SSH access to Synology configured

**Infrastructure:**
- **Host**: Synology NAS
- **Container**: `wavelog-synology` on port 3080
- **Database**: `wavelog-db-synology` (MariaDB 11.3)
- **Tunnel**: `cloudflared-oeradio` (shared with other oeradio.at services)
- **Data**: `/volume1/docker/wavelog/`

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Cloudflare Tunnel                     │
│                 wavelog.oeradio.at → :80                │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│                   Docker Network                         │
│                 (wavelog-network)                        │
│  ┌─────────────────┐      ┌─────────────────────────┐  │
│  │    wavelog      │      │     wavelog-db          │  │
│  │  (PHP/Apache)   │◄────►│    (MariaDB 11.3)       │  │
│  │    Port 80      │      │    Port 3306            │  │
│  └─────────────────┘      └─────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Containers

| Container | Image | Port | Health Check |
|-----------|-------|------|--------------|
| wavelog | ghcr.io/wavelog/wavelog:latest | 80 | curl http://localhost/ |
| wavelog-db | mariadb:11.3 | 3306 | healthcheck.sh --connect |
| wavelog-backup | custom (Dockerfile.backup) | - | - |

## Data Persistence

| Type | Location | Docker Volume/Mount |
|------|----------|---------------------|
| Database | MariaDB data | wavelog-dbdata (volume) |
| Config | /var/www/html/application/config/docker | wavelog-config (volume) |
| Uploads | ./uploads | bind mount |
| User data | ./userdata | bind mount |
| Backups | ./backup | bind mount |
| DB Init | ./init | bind mount (read-only) |

## Database

| Setting | Value |
|---------|-------|
| Host | wavelog-db-synology (inside Docker network) |
| Database | wavelog |
| User | wavelog |
| Password | (see docker-compose.yml) |
| QSO Count | ~10,210 |

### Key Tables

- `TABLE_HRD_CONTACTS_V01` - Main QSO log
- `station_logbooks` - Station/logbook definitions
- `station_profile` - Station profiles
- `dxcc_entities` - DXCC entity data

## Configuration Files

### docker-compose.yml
- Defines wavelog and wavelog-db services
- Health checks for both containers
- Volume mounts for persistence
- Network configuration

### Database Config (in container)
Location: `/var/www/html/application/config/docker/database.php`

Must contain hostname pointing to the database container name (e.g., `wavelog-db-synology`).

### App Config (in container)
Location: `/var/www/html/application/config/docker/config.php`

Copied from original installation at `/var/www/wavelog/application/config/config.php`

## Automated Backups

The `wavelog-backup` container handles daily backups.

| Setting | Value |
|---------|-------|
| Schedule | Daily at 3:00 AM (cron inside container) |
| Location | `/backup` (mounted from host) |
| Retention | 30 days (configurable via RETENTION_DAYS env) |
| Format | Compressed SQL (.sql.gz) |

### Backup Files

- `Dockerfile.backup` - Builds backup container with cron
- `backup-db-internal.sh` - Backup script that runs inside container
- `backup-db.sh` - Host-side backup script (alternative)

### Manual Backup Commands

```bash
# Run backup from container
docker exec wavelog-backup /backup-db.sh

# View backup logs
docker exec wavelog-backup cat /var/log/backup.log

# Check cron schedule
docker exec wavelog-backup crontab -l
```

## Common Operations

### Check Status
```bash
docker ps --filter "name=wavelog"
docker inspect --format='{{.State.Health.Status}}' wavelog
docker inspect --format='{{.State.Health.Status}}' wavelog-db
```

### View Logs
```bash
docker compose logs -f
docker compose logs wavelog --tail 100
docker compose logs wavelog-db --tail 100
```

### Restart
```bash
docker compose restart
# or
docker compose down && docker compose up -d
```

### Database Access
```bash
# Shell access (on Synology)
ssh straliadmin@<SYNOLOGY_IP> '/usr/local/bin/docker exec -it wavelog-db-synology mariadb -u wavelog -p wavelog'

# Run query
ssh straliadmin@<SYNOLOGY_IP> '/usr/local/bin/docker exec wavelog-db-synology mariadb -u wavelog -p wavelog -e "SELECT COUNT(*) FROM TABLE_HRD_CONTACTS_V01;"'
```

### Update Wavelog
```bash
docker compose pull
docker compose up -d
```

### Backup Database
```bash
# On Synology
ssh straliadmin@<SYNOLOGY_IP> '/usr/local/bin/docker exec wavelog-db-synology mariadb-dump -u wavelog -p wavelog > /volume1/docker/wavelog/backup/wavelog_$(date +%Y%m%d).sql'
```

### Copy Config to Container
After recreating containers, the database.php config needs to be copied to the container.
The config is stored in the `wavelog-config` Docker volume and persists across container restarts.

## Cloudflare Tunnel

Config file: `/etc/cloudflared/config.yml`

```yaml
ingress:
  - hostname: wavelog.oeradio.at
    service: http://localhost:80
```

## Migration History

**Date:** 2026-01-11

Migrated from:
- Apache/2.4.58 (Ubuntu)
- MariaDB 10.11.13 (local)
- Path: /var/www/wavelog

To:
- Docker containers
- MariaDB 11.3 (containerized)
- Path: /home/oe8yml/oeradiowavelog

### Migration Steps Performed

1. Created docker-compose.yml with wavelog + mariadb services
2. Exported database: `sudo mysqldump wavelog > init/wavelog_backup.sql`
3. Fixed SQL dump (removed sandbox mode comment on line 1)
4. Copied uploads, userdata, backup directories
5. Stopped Apache: `sudo systemctl stop apache2 && sudo systemctl disable apache2`
6. Started Docker containers
7. Copied database.php and config.php to container config volume
8. Stopped local MariaDB: `sudo systemctl stop mariadb && sudo systemctl disable mariadb`

## Troubleshooting

### "Install" page shows instead of login
Config files missing in container. Copy database.php and config.php to docker config volume.

### Database connection error
1. Check wavelog-db container is healthy
2. Verify database.php has correct hostname (wavelog-db, not localhost)
3. Check password matches docker-compose.yml

### Container unhealthy
```bash
docker logs wavelog --tail 50
docker inspect --format='{{json .State.Health}}' wavelog | jq
```

### Permission denied on uploads
```bash
docker exec wavelog chown -R www-data:www-data /var/www/html/uploads
docker exec wavelog chown -R www-data:www-data /var/www/html/userdata
```

### SQL import error "Unknown command '\-'"
Remove first line from SQL dump:
```bash
tail -n +2 init/wavelog_backup.sql > init/wavelog_backup_fixed.sql
mv init/wavelog_backup_fixed.sql init/wavelog_backup.sql
```

## Related Services

| Service | Port | Tunnel |
|---------|------|--------|
| Wavelog | 80 | wavelog.oeradio.at |
| QSL Generator | 3400 | qsl.oeradio.at |
| WebRX | 3300 | webrx.at |

## Git Workflow

```bash
# Make changes
git add .
git commit -m "Description"
git push origin main
```

Note: `init/`, `uploads/`, `userdata/`, `backup/` are gitignored (contain data/secrets).
