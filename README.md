# gitea-backup-s3

[Gitea](https://gitea.io) git server provides a `dump` command which packages all your repositories, configuration and database in a single .zip file.

Through this image you can schedule periodic dumps and automate the transfer of the resulting files to an S3-compatible storage using rclone.

## Features

- Automated Gitea backups using the official `gitea dump` command
- S3-compatible storage support (AWS S3, MinIO, etc.)
- Configurable backup scheduling with cron syntax
- Health check integration for monitoring
- Lightweight Alpine-based image

## Usage

`docker pull ghcr.io/[owner]/docker-gitea-backup-s3`

### Volume

In order to ensure persistence of your data using the [Gitea docker image](https://hub.docker.com/r/gitea/gitea/), you are supposed to mount a host's folder or a data-volume on the `/data` directory inside the Gitea container.

To use this serivice just mount the same folder or data-volume into the `/data` directory of the backup serivice container.

### Environment Variables

Those marked with `*` are mandatory.

#### S3 Configuration
- `AWS_ACCESS_KEY_ID`* - AWS access key ID
- `AWS_SECRET_ACCESS_KEY`* - AWS secret access key
- `S3_BUCKET`* - S3 bucket name
- `S3_REGION`* - S3 region (e.g., `us-east-1`)
- `S3_ENDPOINT` - Custom S3 endpoint for MinIO or other S3-compatible services
- `S3_PREFIX` - Prefix for backup files in bucket (without leading/trailing `/`)
- `S3_ENCRYPT` - Set to `yes` to enable S3 server-side AES-256 encryption

#### Backup Configuration
- `SCHEDULE` - Cron schedule for backups (see [cron syntax](https://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules)). Use numeric values for days: 0=Sunday, 1=Monday, etc. If not set, backup runs once and container exits
- `GITEA_USER` - User to run gitea dump command (default: `git`)
- `GITEA_CUSTOM` - Path to Gitea custom directory (default: `/data/gitea`)
- `TZ` - Timezone for cron scheduling (default: `UTC`, e.g., `Europe/Moscow`, `America/New_York`)

#### Monitoring
- `HEALTHCHECK` - Health check URL (https://healthchecks.io/ping/<id>) for monitoring (optional)

## Cron Schedule Examples

- `0 2 * * *` - Daily at 2:00 AM
- `0 3 * * 1` - Every Monday at 3:00 AM
- `0 4 * * 0` - Every Sunday at 4:00 AM
- `30 1 1 * *` - 1st day of month at 1:30 AM

## Examples

### Basic Usage with AWS S3
```bash
docker run -d \
  --name gitea-backup \
  -v gitea_data:/data \
  -e AWS_ACCESS_KEY_ID=your_access_key \
  -e AWS_SECRET_ACCESS_KEY=your_secret_key \
  -e S3_BUCKET=my-gitea-backups \
  -e S3_REGION=us-east-1 \
  -e SCHEDULE="0 2 * * *" \
  -e TZ=Europe/Moscow \
  ghcr.io/[owner]/docker-gitea-backup-s3
```

### MinIO Configuration
```bash
docker run -d \
  --name gitea-backup \
  -v gitea_data:/data \
  -e AWS_ACCESS_KEY_ID=minio_access_key \
  -e AWS_SECRET_ACCESS_KEY=minio_secret_key \
  -e S3_BUCKET=gitea-backups \
  -e S3_REGION=us-east-1 \
  -e S3_ENDPOINT=https://minio.example.com \
  -e S3_PREFIX=backups \
  -e SCHEDULE="0 3 * * 1" \
  -e HEALTHCHECK=https://healthchecks.io/ping/<id> \
  ghcr.io/[owner]/docker-gitea-backup-s3
```

### Docker Compose
```yaml
version: '3.8'
services:
  gitea-backup:
    image: ghcr.io/[owner]/docker-gitea-backup-s3
    volumes:
      - gitea_data:/data
    environment:
      - AWS_ACCESS_KEY_ID=your_access_key
      - AWS_SECRET_ACCESS_KEY=your_secret_key
      - S3_BUCKET=my-gitea-backups
      - S3_REGION=us-east-1
      - SCHEDULE=0 2 * * *
      - HEALTHCHECK=https://healthchecks.io/ping/<id>
```

## Monitoring

### Logs
When running with a schedule, logs are written to `/var/log/backup.log` inside the container:
```bash
docker exec container_name tail -f /var/log/backup.log
```

### Health Check Integration
If `HEALTHCHECK` environment variable is set, the service will send a GET request to the specified URL after successful backup upload. This can be used with services like Healthchecks.io for monitoring.

## Build from Source

```bash
git clone https://github.com/[owner]/docker-gitea-backup-s3
cd docker-gitea-backup-s3
docker build -t gitea-backup-s3 .
```
