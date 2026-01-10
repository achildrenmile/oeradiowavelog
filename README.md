# OE Radio Wavelog Docker Setup

Docker deployment for [Wavelog](https://www.wavelog.org/) amateur radio logging software.

## Services

- **wavelog** - Wavelog web application (PHP/Apache)
- **wavelog-db** - MariaDB 11.3 database

## Quick Start

### Fresh Installation

```bash
./deploy-docker.sh
```

Then access http://localhost:80 and follow the installation wizard.

### Migration from Existing Installation

1. Export your existing database:
   ```bash
   sudo mysqldump wavelog > init/wavelog_backup.sql
   ```

2. Copy your data directories:
   ```bash
   cp -r /var/www/wavelog/uploads ./uploads
   cp -r /var/www/wavelog/userdata ./userdata
   cp -r /var/www/wavelog/backup ./backup
   ```

3. Stop Apache:
   ```bash
   sudo systemctl stop apache2
   sudo systemctl disable apache2
   ```

4. Deploy:
   ```bash
   ./deploy-docker.sh
   ```

5. Configure database connection in Wavelog:
   - Host: `wavelog-db`
   - Database: `wavelog`
   - User: `wavelog`
   - Password: (as configured in docker-compose.yml)

## Configuration

### Database Password

Edit `docker-compose.yml` to change the database password:

```yaml
MARIADB_PASSWORD: YourSecurePassword
```

### Port

Default port is 80. To change, edit the ports mapping:

```yaml
ports:
  - "8086:80"
```

## Data Persistence

| Directory | Purpose |
|-----------|---------|
| `init/` | SQL files for database initialization |
| `uploads/` | User uploaded files |
| `userdata/` | User-specific data |
| `backup/` | Wavelog backups |

Database data is stored in a Docker volume (`wavelog-dbdata`).

## Management

```bash
# Start
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f

# Restart
docker compose restart

# Update Wavelog
docker compose pull
docker compose up -d
```

## Health Checks

Both containers have health checks configured:
- Database: checks MySQL connectivity
- Wavelog: checks HTTP response

```bash
# Check status
docker ps --filter "name=wavelog"
```

## External Access

Configured for Cloudflare Tunnel access at `wavelog.oeradio.at`.
