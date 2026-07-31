#! /bin/sh

set -e

# Add timestamp to logs
echo "=== Backup started at $(date) ==="

BACKUP_OK=no

# Healthchecks.io style signalling: "/start" when the run begins, plain URL on
# success, "/fail" on any failure. Without the failure signal a broken run is
# only noticed once the grace period expires - and the next successful run
# clears the alert before anyone sees it.
hc_ping () {
  SUFFIX=$1

  if [ "${HEALTHCHECK}" = "**None**" ] || [ -z "${HEALTHCHECK}" ]; then
    return 0
  fi

  # -f so an HTTP error from the monitoring service is not treated as success
  if curl -fsS -m 10 --retry 5 -o /dev/null "${HEALTHCHECK%/}${SUFFIX}"; then
    echo "Healthcheck sent: ${SUFFIX:-success}"
  else
    >&2 echo "Warning: healthcheck '${SUFFIX:-success}' could not be delivered"
  fi

  # Monitoring must never decide the fate of the backup itself
  return 0
}

# Any exit before BACKUP_OK is set - failed validation, failed dump, failed
# upload, or an unexpected error under "set -e" - reports a failure.
on_exit () {
  EXIT_CODE=$?

  if [ "$BACKUP_OK" != "yes" ]; then
    hc_ping /fail
  fi

  exit $EXIT_CODE
}
trap on_exit EXIT

hc_ping /start

if [ "${AWS_ACCESS_KEY_ID}" = "**None**" ]; then
  echo "Warning: You did not set the AWS_ACCESS_KEY_ID environment variable."
fi

if [ "${AWS_SECRET_ACCESS_KEY}" = "**None**" ]; then
  echo "Warning: You did not set the AWS_SECRET_ACCESS_KEY environment variable."
fi

if [ "${S3_BUCKET}" = "**None**" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ "${S3_REGION}" = "**None**" ]; then
  echo "You need to set the S3_REGION environment variable."
  exit 1
fi

# Configure rclone for S3
echo "Configuring rclone..."
mkdir -p ~/.config/rclone

# Build rclone config
RCLONE_CONFIG="[s3]
type = s3
provider = ${S3_PROVIDER}
access_key_id = ${AWS_ACCESS_KEY_ID}
secret_access_key = ${AWS_SECRET_ACCESS_KEY}
region = ${S3_REGION}"

if [ "${S3_ENDPOINT}" != "**None**" ]; then
  RCLONE_CONFIG="${RCLONE_CONFIG}
endpoint = ${S3_ENDPOINT}"
fi

if [ "${S3_ENCRYPT}" = "yes" ]; then
  RCLONE_CONFIG="${RCLONE_CONFIG}
server_side_encryption = AES256"
fi

echo "$RCLONE_CONFIG" > ~/.config/rclone/rclone.conf

move_to_s3 () {
  SRC_FILE=$1
  DEST_FILE=$2

  echo "Uploading ${DEST_FILE} to S3: ${S3_BUCKET}/${S3_PREFIX:+${S3_PREFIX}/}"

  rclone copy "$SRC_FILE" "s3:${S3_BUCKET}/${S3_PREFIX:+${S3_PREFIX}/}" --s3-no-check-bucket

  if [ $? != 0 ]; then
    >&2 echo "Error uploading ${DEST_FILE} to S3"
    return 1
  fi

  rm "$SRC_FILE"
  return 0
}

rotate_backups () {
  REMOTE_PATH="s3:${S3_BUCKET}/${S3_PREFIX:+${S3_PREFIX}/}"
  KEEP="${BACKUP_KEEP_COUNT}"

  # Rotation must never wipe out every backup: anything non-numeric,
  # empty or below 1 falls back to keeping a single copy.
  case "$KEEP" in
    ''|*[!0-9]*)
      echo "Rotation: invalid BACKUP_KEEP_COUNT='${BACKUP_KEEP_COUNT}', falling back to 1"
      KEEP=1
      ;;
  esac

  if [ "$KEEP" -lt 1 ]; then
    echo "Rotation: BACKUP_KEEP_COUNT=${KEEP} is below the minimum, falling back to 1"
    KEEP=1
  fi

  echo "Rotating backups in ${S3_BUCKET}/${S3_PREFIX:+${S3_PREFIX}/} (keeping ${KEEP})"

  # "<mtime>|<name>", oldest first. rclone prints mtime as "YYYY-MM-DD HH:MM:SS",
  # so a plain lexicographic sort is chronological.
  LISTING=$(rclone lsf "$REMOTE_PATH" --files-only --include "${BACKUP_PATTERN}" \
    --format "tp" --separator "|" | sort)

  if [ -z "$LISTING" ]; then
    echo "Rotation: nothing matching '${BACKUP_PATTERN}' found, skipping"
    return 0
  fi

  TOTAL=$(echo "$LISTING" | wc -l | tr -d ' ')
  DELETE_COUNT=$((TOTAL - KEEP))

  if [ "$DELETE_COUNT" -le 0 ]; then
    echo "Rotation: ${TOTAL} backup(s) stored, limit is ${KEEP} - nothing to delete"
    return 0
  fi

  echo "Rotation: ${TOTAL} backup(s) stored, removing ${DELETE_COUNT} oldest"

  echo "$LISTING" | head -n "$DELETE_COUNT" | while IFS= read -r ENTRY; do
    NAME=${ENTRY#*|}

    # Belt and braces: never drop the dump this run has just uploaded
    if [ "$NAME" = "$CURRENT_BACKUP" ]; then
      echo "Rotation: keeping ${NAME} (uploaded by this run)"
      continue
    fi

    if rclone deletefile "${REMOTE_PATH}${NAME}"; then
      echo "Rotation: deleted ${NAME}"
    else
      >&2 echo "Rotation: failed to delete ${NAME}"
    fi
  done

  return 0
}

BACKUP_START_TIME=$(date +"%Y-%m-%dT%H%M%SZ")
S3_FILE="${BACKUP_START_TIME}.gitea-dump.zip"

cd /backup
echo "Dumping Gitea..."
su -c "/usr/local/bin/gitea dump ${GITEA_DUMP_ARGS}" $GITEA_USER
echo "Done"

# Find the newest dump file
DUMP_FILE=""
for FILE in /backup/*.zip; do
  if [ -f "$FILE" ] && [ -z "$DUMP_FILE" -o "$FILE" -nt "$DUMP_FILE" ]; then
    DUMP_FILE="$FILE"
  fi
done

if [ -z "$DUMP_FILE" ]; then
  echo "Error: No dump file found"
  exit 1
fi

# rclone copy keeps the source basename, so this is the object name in S3
CURRENT_BACKUP=$(basename "$DUMP_FILE")

if move_to_s3 "$DUMP_FILE" "$S3_FILE"; then
  echo "Backup uploaded successfully"

  # The backup is safely in S3 from here on: housekeeping below may warn,
  # but must not turn a good run into a reported failure.
  BACKUP_OK=yes

  # Rotate only after a confirmed upload. A rotation failure leaves the
  # fresh backup in place, so it must not fail the whole run.
  if [ "${BACKUP_ROTATION}" = "yes" ]; then
    if ! rotate_backups; then
      >&2 echo "Warning: rotation failed, backup itself is intact"
    fi
  fi

  # Success ping only after the upload was confirmed
  hc_ping ""

  echo "Gitea backup finished successfully at $(date)"
else
  echo "Backup failed - upload to S3 unsuccessful at $(date)"
  # on_exit sends the /fail signal
  exit 1
fi

echo "=== Backup completed at $(date) ==="
