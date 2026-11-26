#!/usr/bin/env bash
# Mirror the LifeForge docs (Flutter app + API) into the FunWork project on the VPS.
# Usage: scripts/sync-funwork-docs.sh
set -euo pipefail

SSH_HOST="funwork"
PROJECT_ID=3
CONTAINER="funwork-app-1"
STAGING_DIR="funwork/src/storage/app/lifeforge-docs"
CONTAINER_DIR="/app/storage/app/lifeforge-docs"

FRONTEND_DOCS="$HOME/Work/lifeforge/docs/"
BACKEND_DOCS="$HOME/Work/lifeforge-api/docs/"

ssh "$SSH_HOST" "mkdir -p $STAGING_DIR/frontend $STAGING_DIR/backend"
rsync -az --delete "$FRONTEND_DOCS" "$SSH_HOST:$STAGING_DIR/frontend/"
rsync -az --delete "$BACKEND_DOCS" "$SSH_HOST:$STAGING_DIR/backend/"

# Replace the container copy so files deleted locally are also removed there.
ssh "$SSH_HOST" "
  set -e
  docker exec -u root $CONTAINER rm -rf $CONTAINER_DIR
  docker cp ~/$STAGING_DIR $CONTAINER:$CONTAINER_DIR
  docker exec $CONTAINER php artisan funwork:sync-docs $PROJECT_ID --area=frontend --path=$CONTAINER_DIR/frontend
  docker exec $CONTAINER php artisan funwork:sync-docs $PROJECT_ID --area=backend --path=$CONTAINER_DIR/backend
"
