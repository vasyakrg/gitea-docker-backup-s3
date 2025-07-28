#!/bin/bash

docker buildx build --platform linux/arm64 --load -t vasyakrg/gitea-docker-backup-s3:latest \
  --build-arg DOCKER_BASEIMAGE=ghcr.io/catthehacker/ubuntu:act-latest .
