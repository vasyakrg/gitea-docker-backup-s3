FROM alpine:3.22

ENV S3_BUCKET=**None** \
    S3_REGION=**None** \
    S3_ENDPOINT=**None** \
    S3_S3V4=no \
    S3_PREFIX=**None** \
    S3_ENCRYPT=no \
    SCHEDULE=**None** \
    GITEA_USER=git \
    GITEA_CUSTOM=/data/gitea

RUN adduser -D -s /bin/sh git

ADD install.sh install.sh
RUN sh install.sh && rm install.sh

ADD run.sh run.sh
ADD backup.sh backup.sh

VOLUME ["/data"]
EXPOSE 8080

CMD ["sh", "run.sh"]
