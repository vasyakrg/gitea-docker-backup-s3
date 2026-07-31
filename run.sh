#! /bin/sh

set -e

# Set timezone
if [ -n "$TZ" ] && [ -f "/usr/share/zoneinfo/$TZ" ]; then
  ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
  echo "$TZ" > /etc/timezone
  echo "Timezone set to: $TZ"
fi

if [ "${SCHEDULE}" = "**None**" ]; then
  # Run backup once and exit
  sh /backup.sh
else
  # Create log directory and crontab
  mkdir -p /var/log

  # crond runs jobs with a nearly empty environment: dump the container's env
  # to a file and source it from the cron entry, otherwise S3_*/AWS_*/GITEA_*
  # are unset inside the job and the backup silently targets an empty bucket.
  export PATH="/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
  export -p > /etc/backup.env
  chmod 600 /etc/backup.env

  # Create crontab entry
  echo "${SCHEDULE} . /etc/backup.env && sh /backup.sh >> /var/log/backup.log 2>&1" > /etc/crontabs/root

  echo "Starting crond with schedule: $SCHEDULE"
  echo "Logs available at: /var/log/backup.log (crond: /var/log/crond.log)"

  # Start crond in foreground
  exec crond -f -l 2 -c /etc/crontabs -L /var/log/crond.log
fi
