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
provider = AWS
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

  if [ "${S3_PREFIX}" == "**None**" ]; then
    S3_PATH="s3:${S3_BUCKET}/${DEST_FILE}"
  else
    S3_PATH="s3:${S3_BUCKET}/${S3_PREFIX}/${DEST_FILE}"
  fi

  echo "Uploading ${DEST_FILE} to S3..."

  rclone copy "$SRC_FILE" "$S3_PATH"

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

unset -v DUMP_FILE
for FILE in /backup/*; do
  [[ $FILE -nt $DUMP_FILE ]] && DUMP_FILE=$FILE;
done

move_to_s3 "$DUMP_FILE" "$S3_FILE"

echo "Gitea backup finished"
