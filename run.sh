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

  # Create crontab entry
  echo "${SCHEDULE} /backup.sh >> /var/log/backup.log 2>&1" > /etc/crontabs/root

  echo "Starting crond with schedule: $SCHEDULE"
  echo "Logs available at: /var/log/backup.log"

  # Start crond in foreground
  exec crond -f -l 2
fi
