# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Что это

Docker-образ (Alpine) для периодического бэкапа Gitea: выполняет `gitea dump` и заливает получившийся архив в S3-совместимое хранилище через rclone. Кода нет — только четыре POSIX `sh`-скрипта и Dockerfile.

## Команды

```bash
# Локальная сборка (внимание: скрипт собирает под arm64)
./docker-build.sh

# Обычная сборка
docker build -t gitea-backup-s3 .

# Разовый прогон бэкапа (без SCHEDULE контейнер отрабатывает и выходит)
docker run --rm -v gitea_data:/data \
  -e AWS_ACCESS_KEY_ID=... -e AWS_SECRET_ACCESS_KEY=... \
  -e S3_BUCKET=... -e S3_REGION=us-east-1 \
  gitea-backup-s3

# Логи при работе по расписанию
docker exec <container> tail -f /var/log/backup.log
```

Тестов и линтеров в репозитории нет. Проверка изменений = собрать образ и прогнать разовый бэкап против тестового бакета (MinIO).

## Архитектура

Три стадии, каждая в своём файле:

1. **`install.sh`** — только build-time (`ADD` + `RUN sh install.sh && rm install.sh`). Ставит `rclone` (latest) и бинарь `gitea` версии `$GITEA_VERSION`, создаёт `/backup` и `/data` с владельцем `git`. Апгрейд Gitea = правка `ENV GITEA_VERSION` в Dockerfile.
2. **`run.sh`** — ENTRYPOINT-логика. Настраивает `TZ` симлинком на `/usr/share/zoneinfo`, затем ветвится: `SCHEDULE=**None**` → однократный `sh /backup.sh` и выход; иначе пишет строку в `/etc/crontabs/root` и `exec crond -f -l 2`.
3. **`backup.sh`** — сама работа. Валидация переменных → генерация `~/.config/rclone/rclone.conf` конкатенацией строк → `su -c "gitea dump $GITEA_DUMP_ARGS" $GITEA_USER` в cwd `/backup` → поиск самого свежего `*.zip` в `/backup` → `rclone copy` в `s3:$S3_BUCKET/$S3_PREFIX/` с `--s3-no-check-bucket` → удаление локального файла → GET на `$HEALTHCHECK`.

### Конвенция `**None**`

Все опциональные переменные задаются в Dockerfile как строка `**None**`, а не оставляются unset. Проверки в скриптах сравнивают именно с этим литералом (`[ "${S3_ENDPOINT}" != "**None**" ]`). Новую переменную нужно объявлять в `ENV` Dockerfile с этим значением, иначе проверка вида `!= "**None**"` пропустит пустую строку в конфиг.

### Известные расхождения

- `S3_PROVIDER` используется в `backup.sh` при генерации `rclone.conf`, но **не объявлена** в `ENV` Dockerfile и не описана в README — при незаданной переменной в конфиг попадает `provider = ` (rclone это переживает, но поведение неочевидно).
- `install.sh` жёстко качает `linux-amd64` бинарники rclone и gitea, а `docker-build.sh` собирает с `--platform linux/arm64`. Multi-arch сборка потребует подстановки арки по `TARGETARCH`.
- Healthcheck отправляется только после успешной загрузки в S3 — это намеренно, не «баг» отсутствия пинга при падении.
- Имя `$S3_FILE` (`<timestamp>.gitea-dump.zip`) вычисляется, но в S3 уезжает исходное имя файла от `gitea dump` — `rclone copy` сохраняет basename. Переменная используется только в логах.

## CI

`.github/workflows/docker-image.yml`: push в `main` или ручной запуск → сборка и push в `ghcr.io/<owner>/docker-gitea-backup-s3:latest`. Тегов версий нет, только `latest`.

## Правки

Скрипты — POSIX `sh` под BusyBox (Alpine), не bash. Никаких `[[ ]]`, массивов, `local` без объявления функции. Все три скрипта работают под `set -e`; `backup.sh` дополнительно полагается на явные `exit 1` при провале валидации.
