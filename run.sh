#! /bin/sh

set -e

if [ "${S3_S3V4}" = "yes" ]; then
    aws configure set default.s3.signature_version s3v4
fi

if [ "${SCHEDULE}" = "**None**" ]; then
  sh /backup.sh
else
  # Create log directory
  mkdir -p /var/log
  echo "Starting scheduled backup with cron: $SCHEDULE"
  exec go-cron -s "$SCHEDULE" -p 8080 -- /bin/sh -c "exec /backup.sh 2>&1 | tee -a /var/log/backup.log"
fi
