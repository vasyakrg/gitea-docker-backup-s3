#!/bin/bash

docker buildx build --platform linux/arm64 --load -t ghcr.io/vasyakrg/docker-gitea-backup-s3:latest .
