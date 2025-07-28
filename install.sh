#! /bin/sh

# exit if a command fails
set -e

export PATH="/usr/local/bin:/usr/bin:/bin"

# install awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
ln -s /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws
rm -rf /tmp/aws /tmp/awscliv2.zip

# install gitea binary
curl -L "https://dl.gitea.io/gitea/1.22.3/gitea-1.22.3-linux-amd64" -o /usr/local/bin/gitea
chmod +x /usr/local/bin/gitea

# install go-cron
curl -L --insecure https://github.com/odise/go-cron/releases/download/v0.0.7/go-cron-linux.gz | zcat > /usr/local/bin/go-cron
chmod u+x /usr/local/bin/go-cron

# make backup directory and change owner to git
mkdir -p /backup /data
chown git /backup /data

# cleanup
rm -rf /var/cache/apk/*
