#! /bin/bash

set -e

if [ "${AWS_ACCESS_KEY_ID}" == "**None**" ]; then
  echo "Warning: You did not set the AWS_ACCESS_KEY_ID environment variable."
fi

if [ "${AWS_SECRET_ACCESS_KEY}" == "**None**" ]; then
  echo "Warning: You did not set the AWS_SECRET_ACCESS_KEY environment variable."
fi

if [ "${S3_BUCKET}" == "**None**" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ "${S3_REGION}" == "**None**" ]; then
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

if [ "${S3_ENCRYPT}" == "yes" ]; then
  RCLONE_CONFIG="${RCLONE_CONFIG}
server_side_encryption = AES256"
fi

echo "$RCLONE_CONFIG" > ~/.config/rclone/rclone.conf

move_to_s3 () {
  SRC_FILE=$1
  DEST_FILE=$2

  echo "Uploading ${DEST_FILE} to S3..."

  rclone copy "$SRC_FILE" "s3:${S3_BUCKET}/${S3_PREFIX:+${S3_PREFIX}/}${DEST_FILE}"

  if [ $? != 0 ]; then
    >&2 echo "Error uploading ${DEST_FILE} to S3"
  fi

  rm "$SRC_FILE"
}

BACKUP_START_TIME=$(date +"%Y-%m-%dT%H%M%SZ")
S3_FILE="${BACKUP_START_TIME}.gitea-dump.zip"

cd /backup
echo "Dumping Gitea..."
su -c "/usr/local/bin/gitea dump" $GITEA_USER
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

move_to_s3 "$DUMP_FILE" "$S3_FILE"

echo "Gitea backup finished"
