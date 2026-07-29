#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

APP_DIR="${APP_DIR:-/opt/arkinterview}"
API_URL="${API_URL:-http://127.0.0.1:8787/api}"
DB_FILE="${DB_FILE:-${APP_DIR}/backend/storage/arkinterview.sqlite}"
LEGACY_DB_FILE="${LEGACY_DB_FILE:-${APP_DIR}/backend/storage/db.json}"
BACKUP_DIR="${BACKUP_DIR:-${APP_DIR}/.deploy-backups}"

if [[ -z "${ADMIN_TOKEN:-}" || ${#ADMIN_TOKEN} -lt 32 ]]; then
  echo "ADMIN_TOKEN must contain at least 32 characters." >&2
  exit 1
fi

if [[ -n "${HUAWEI_CLIENT_ID:-}${HUAWEI_CLIENT_SECRET:-}${HUAWEI_REDIRECT_URI:-}" ]] &&
  [[ -z "${HUAWEI_CLIENT_ID:-}" || -z "${HUAWEI_CLIENT_SECRET:-}" || -z "${HUAWEI_REDIRECT_URI:-}" ]]; then
  echo "HUAWEI_CLIENT_ID, HUAWEI_CLIENT_SECRET, and HUAWEI_REDIRECT_URI must be configured together." >&2
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

node -e '
  const [major, minor] = process.versions.node.split(".").map(Number);
  if (major < 20 || (major === 20 && minor < 17)) {
    console.error(`Node.js >= 20.17.0 is required, current version: ${process.versions.node}`);
    process.exit(1);
  }
'

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ "${ALLOW_DIRTY_DEPLOY:-0}" != "1" ]] && {
    ! git diff --quiet || ! git diff --cached --quiet;
  }; then
    echo "Refusing to deploy a dirty Git worktree. Commit the release or set ALLOW_DIRTY_DEPLOY=1 explicitly." >&2
    exit 1
  fi
fi

npm ci --omit=dev

export NODE_ENV=production
export HOST="${HOST:-0.0.0.0}"
export PORT="${PORT:-8787}"
export DB_FILE
export LEGACY_DB_FILE
export ADMIN_TOKEN
export HUAWEI_CLIENT_ID="${HUAWEI_CLIENT_ID:-}"
export HUAWEI_CLIENT_SECRET="${HUAWEI_CLIENT_SECRET:-}"
export HUAWEI_REDIRECT_URI="${HUAWEI_REDIRECT_URI:-}"
export AUTH_ACCESS_TTL_SECONDS="${AUTH_ACCESS_TTL_SECONDS:-900}"
export AUTH_REFRESH_TTL_SECONDS="${AUTH_REFRESH_TTL_SECONDS:-2592000}"
export ADMIN_SESSION_TTL_SECONDS="${ADMIN_SESSION_TTL_SECONDS:-28800}"
export ADMIN_LOGIN_WINDOW_SECONDS="${ADMIN_LOGIN_WINDOW_SECONDS:-900}"
export ADMIN_LOGIN_LOCK_SECONDS="${ADMIN_LOGIN_LOCK_SECONDS:-900}"
export ADMIN_LOGIN_MAX_FAILURES="${ADMIN_LOGIN_MAX_FAILURES:-5}"
export TRUST_PROXY="${TRUST_PROXY:-0}"

npm test

legacy_migration=0
if [[ ! -f "${DB_FILE}" && -f "${LEGACY_DB_FILE}" ]]; then
  legacy_migration=1
  if pm2 describe arkinterview >/dev/null 2>&1; then
    pm2 stop arkinterview
  fi
fi

backup_file=""
if [[ -f "${DB_FILE}" ]]; then
  mkdir -p "${BACKUP_DIR}"
  chmod 700 "${BACKUP_DIR}"
  backup_file="${BACKUP_DIR}/arkinterview-$(date -u +%Y%m%dT%H%M%SZ).sqlite"
  node scripts/backup-sqlite.mjs "${DB_FILE}" "${backup_file}"
  chmod 600 "${backup_file}"
elif [[ -f "${LEGACY_DB_FILE}" ]]; then
  mkdir -p "${BACKUP_DIR}"
  chmod 700 "${BACKUP_DIR}"
  backup_file="${BACKUP_DIR}/legacy-db-$(date -u +%Y%m%dT%H%M%SZ).json"
  cp "${LEGACY_DB_FILE}" "${backup_file}"
  chmod 600 "${backup_file}"
fi

npm run questions:sync-db
pm2 startOrReload ecosystem.config.cjs --update-env
pm2 save

curl --fail --silent --show-error "${API_URL}/categories" >/dev/null
curl --fail --silent --show-error "${API_URL}/auth/status" >/dev/null

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

echo "Deployment verified: public API, auth status, and admin authentication are healthy."
if [[ "${legacy_migration}" == "1" ]]; then
  echo "Legacy JSON data migrated to SQLite: ${DB_FILE}"
fi
if [[ -n "${backup_file}" ]]; then
  echo "Database backup: ${backup_file}"
fi
