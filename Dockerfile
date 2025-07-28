FROM gitea/gitea:latest AS source-image

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

COPY --from=source-image /app /app
COPY --from=source-image /etc /etc
COPY --from=source-image /usr /usr
COPY --from=source-image /bin /bin
COPY --from=source-image /lib /lib
COPY --from=source-image /sbin /sbin

RUN mkdir -p /data

ADD install.sh install.sh
RUN sh install.sh && rm install.sh

ADD run.sh run.sh
ADD backup.sh backup.sh

VOLUME ["/data"]
EXPOSE 8080

CMD ["sh", "run.sh"]
