# OE Radio Wavelog

Docker deployment for [Wavelog](https://www.wavelog.org/) amateur radio logging software for OE8YML.

**Live URL:** https://wavelog.oeradio.at

## Services

| Container | Image | Port | Purpose |
|-----------|-------|------|---------|
| wavelog | ghcr.io/wavelog/wavelog:latest | 80 | Wavelog web application |
| wavelog-db | mariadb:11.3 | 3306 (internal) | MariaDB database |
| wavelog-backup | custom (Dockerfile.backup) | - | Daily database backups |

## Quick Start

```bash
# Deploy
./deploy-docker.sh

# Or manually
docker compose up -d
```

## Directory Structure

```
oeradiowavelog/
├── docker-compose.yml    # Docker services configuration
├── deploy-docker.sh      # Deployment script
├── init/                 # Database initialization (SQL dumps)
│   └── wavelog_backup.sql
├── uploads/              # User uploaded files (QSL cards, etc.)
├── userdata/             # User-specific data
└── backup/               # Wavelog backups
```

## Configuration

### Database Credentials

| Setting | Value |
|---------|-------|
| Host | wavelog-db |
| Database | wavelog |
| User | wavelog |
| Password | WavelogPass123 |

To change the password, edit `docker-compose.yml`:

```yaml
MARIADB_PASSWORD: YourNewPassword
```

### Port Configuration

Default port is 80. To change:

```yaml
ports:
  - "8086:80"
```

## Management Commands

```bash
# Start containers
docker compose up -d

# Stop containers
docker compose down

# View logs
docker compose logs -f
docker compose logs wavelog --tail 50
docker compose logs wavelog-db --tail 50

# Restart
docker compose restart

# Check status
docker ps --filter "name=wavelog"

# Check health
docker inspect --format='{{.State.Health.Status}}' wavelog
docker inspect --format='{{.State.Health.Status}}' wavelog-db
```

## Update Wavelog

```bash
# Pull latest image
docker compose pull

# Recreate container
docker compose up -d
```

## Automated Backups

The `wavelog-backup` container runs daily backups at **3:00 AM**.

### Backup Configuration

| Setting | Value |
|---------|-------|
| Schedule | Daily at 3:00 AM |
| Location | `/backup` (host) |
| Retention | 30 days |
| Format | Compressed SQL (.sql.gz) |

### Manual Backup

```bash
# Run backup manually
docker exec wavelog-backup /backup-db.sh

# View backup logs
docker exec wavelog-backup cat /var/log/backup.log

# List backups
ls -la /backup/
```

### Restore from Backup

```bash
# Stop wavelog
docker compose stop wavelog

# Restore database
gunzip -c /backup/wavelog_YYYYMMDD_HHMMSS.sql.gz | \
  docker exec -i wavelog-db mariadb -u wavelog -pWavelogPass123 wavelog

# Start wavelog
docker compose start wavelog
```

## Database Operations

```bash
# Access database shell
docker exec -it wavelog-db mariadb -u wavelog -pWavelogPass123 wavelog

# Check QSO count
docker exec wavelog-db mariadb -u wavelog -pWavelogPass123 wavelog \
  -e "SELECT COUNT(*) FROM TABLE_HRD_CONTACTS_V01;"

# Backup database
docker exec wavelog-db mariadb-dump -u wavelog -pWavelogPass123 wavelog \
  > backup/wavelog_$(date +%Y%m%d).sql

# Restore database
docker exec -i wavelog-db mariadb -u wavelog -pWavelogPass123 wavelog \
  < backup/wavelog_backup.sql
```

## Backup & Restore

### Full Backup

```bash
# Stop containers
docker compose down

# Backup database volume
docker run --rm -v oeradiowavelog_wavelog-dbdata:/data -v $(pwd):/backup \
  alpine tar czf /backup/db-backup.tar.gz -C /data .

# Backup data directories
tar czf data-backup.tar.gz uploads userdata backup

# Start containers
docker compose up -d
```

### Restore

```bash
# Stop containers
docker compose down

# Restore database volume
docker run --rm -v oeradiowavelog_wavelog-dbdata:/data -v $(pwd):/backup \
  alpine sh -c "rm -rf /data/* && tar xzf /backup/db-backup.tar.gz -C /data"

# Restore data directories
tar xzf data-backup.tar.gz

# Start containers
docker compose up -d
```

## Troubleshooting

### Container won't start

```bash
docker compose logs wavelog
docker compose logs wavelog-db
```

### Database connection issues

Verify database is healthy:
```bash
docker exec wavelog-db mariadb -u wavelog -pWavelogPass123 -e "SELECT 1;"
```

Check config files exist:
```bash
docker exec wavelog ls -la /var/www/html/application/config/docker/
```

### Permission issues

```bash
docker exec wavelog chown -R www-data:www-data /var/www/html/uploads
docker exec wavelog chown -R www-data:www-data /var/www/html/userdata
```

### Health check failing

```bash
# Check what health check returns
docker exec wavelog curl -s http://localhost/

# View health check logs
docker inspect --format='{{json .State.Health}}' wavelog | jq
```

## External Access

Exposed via Cloudflare Tunnel:

| Hostname | Target |
|----------|--------|
| wavelog.oeradio.at | localhost:80 |

Tunnel config: `/etc/cloudflared/config.yml`

## Migration from Apache

If migrating from an existing Apache installation:

1. Export database:
   ```bash
   sudo mysqldump wavelog > init/wavelog_backup.sql
   ```

2. Copy data:
   ```bash
   cp -r /var/www/wavelog/uploads/* uploads/
   cp -r /var/www/wavelog/userdata/* userdata/
   ```

3. Stop Apache:
   ```bash
   sudo systemctl stop apache2
   sudo systemctl disable apache2
   ```

4. Deploy Docker:
   ```bash
   ./deploy-docker.sh
   ```

5. Copy config to container:
   ```bash
   docker cp /var/www/wavelog/application/config/config.php \
     wavelog:/var/www/html/application/config/docker/
   ```

## Resources

- [Wavelog Official Site](https://www.wavelog.org/)
- [Wavelog GitHub](https://github.com/wavelog/wavelog)
- [Wavelog Docker Wiki](https://github.com/wavelog/wavelog/wiki/Installation-via-Docker)
- [Wavelog Documentation](https://github.com/wavelog/wavelog/wiki)
