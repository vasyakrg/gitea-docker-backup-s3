#! /bin/sh

# exit if a command fails
set -e
set -x

export PATH="/usr/local/bin:/usr/bin:/bin"

echo "Installing rclone..."
curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip
unzip rclone-current-linux-amd64.zip
cp rclone-*-linux-amd64/rclone /usr/local/bin/
chmod +x /usr/local/bin/rclone
rm -rf rclone-*
rclone version
echo "rclone installed successfully"

echo "Installing gitea binary..."
curl -L "https://dl.gitea.io/gitea/${GITEA_VERSION}/gitea-${GITEA_VERSION}-linux-amd64" -o /usr/local/bin/gitea
chmod +x /usr/local/bin/gitea
echo "gitea binary installed successfully"

echo "Installing go-cron..."
curl -L --insecure https://github.com/odise/go-cron/releases/download/v0.0.7/go-cron-linux.gz | zcat > /usr/local/bin/go-cron
chmod u+x /usr/local/bin/go-cron
echo "go-cron installed successfully"

echo "Creating directories..."
mkdir -p /backup /data
chown git /backup /data
echo "directories created successfully"

echo "Cleanup..."
rm -rf /var/cache/apk/*
echo "cleanup completed"
