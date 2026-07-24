#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

APP_DIR="${APP_DIR:-/opt/arkinterview}"
API_URL="${API_URL:-http://127.0.0.1:8787/api}"
DB_FILE="${DB_FILE:-${APP_DIR}/backend/storage/db.json}"
BACKUP_DIR="${BACKUP_DIR:-${APP_DIR}/.deploy-backups}"

if [[ -z "${ADMIN_TOKEN:-}" || ${#ADMIN_TOKEN} -lt 32 ]]; then
  echo "ADMIN_TOKEN must contain at least 32 characters." >&2
  exit 1
fi

for command_name in node npm pm2 curl; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
done

if [[ ! -f "${APP_DIR}/package.json" || ! -f "${APP_DIR}/backend/server.mjs" ]]; then
  echo "ArkInterview source was not found in APP_DIR=${APP_DIR}" >&2
  exit 1
fi

cd "${APP_DIR}"

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ "${ALLOW_DIRTY_DEPLOY:-0}" != "1" ]] && {
    ! git diff --quiet || ! git diff --cached --quiet;
  }; then
    echo "Refusing to deploy a dirty Git worktree. Commit the release or set ALLOW_DIRTY_DEPLOY=1 explicitly." >&2
    exit 1
  fi
fi

backup_file=""
if [[ -f "${DB_FILE}" ]]; then
  mkdir -p "${BACKUP_DIR}"
  chmod 700 "${BACKUP_DIR}"
  backup_file="${BACKUP_DIR}/db-$(date -u +%Y%m%dT%H%M%SZ).json"
  cp "${DB_FILE}" "${backup_file}"
  chmod 600 "${backup_file}"
fi

export NODE_ENV=production
export HOST="${HOST:-0.0.0.0}"
export PORT="${PORT:-8787}"
export DB_FILE
export ADMIN_TOKEN

npm test
npm run questions:build
pm2 startOrReload ecosystem.config.cjs --update-env
pm2 save

curl --fail --silent --show-error "${API_URL}/categories" >/dev/null

unauthorized_status="$(
  curl --silent --show-error --output /dev/null --write-out "%{http_code}" \
    "${API_URL}/admin/questions"
)"
if [[ "${unauthorized_status}" != "401" ]]; then
  echo "Expected unauthenticated admin request to return 401, got ${unauthorized_status}." >&2
  exit 1
fi

authorized_status="$(
  curl --silent --show-error --output /dev/null --write-out "%{http_code}" \
    --header "Authorization: Bearer ${ADMIN_TOKEN}" \
    "${API_URL}/admin/questions"
)"
if [[ "${authorized_status}" != "200" ]]; then
  echo "Expected authenticated admin request to return 200, got ${authorized_status}." >&2
  exit 1
fi

echo "Deployment verified: public API is healthy and admin authentication is enabled."
if [[ -n "${backup_file}" ]]; then
  echo "Database backup: ${backup_file}"
fi
