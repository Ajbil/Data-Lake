#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_ROOT/.env}"
ENV_EXAMPLE="$REPO_ROOT/.env.example"
COMPOSE_FILE="$REPO_ROOT/infra/docker-compose/docker-compose.yml"

log() {
  printf '\n%s\n' "$*"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    return 1
  fi
}

require_env_file() {
  if [[ ! -f "$ENV_FILE" ]]; then
    printf 'Missing .env. Run ./scripts/setup.sh init first.\n' >&2
    return 1
  fi
}

read_env() {
  local name="$1"
  local value
  value="$(awk -F= -v key="$name" '
    $0 !~ /^[[:space:]]*#/ && $1 == key {
      sub(/^[^=]*=/, "")
      sub(/\r$/, "")
      print
      exit
    }
  ' "$ENV_FILE")"
  if [[ -z "${value}" ]]; then
    printf 'Missing %s in %s\n' "$name" "$ENV_FILE" >&2
    return 1
  fi
  printf '%s' "$value"
}

load_env_exports() {
  require_env_file
  while IFS='=' read -r key value; do
    [[ -z "${key:-}" || "$key" =~ ^[[:space:]]*# ]] && continue
    value="${value%$'\r'}"
    export "$key=$value"
  done < "$ENV_FILE"
}

compose() {
  require_env_file
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

sqlcmd_in_container() {
  local password="$1"
  docker exec -i -e SA_PASSWORD="$password" mbs-sqlserver bash -lc '
    if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then
      /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$SA_PASSWORD"
    elif [ -x /opt/mssql-tools/bin/sqlcmd ]; then
      /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD"
    else
      echo "sqlcmd not found in SQL Server container" >&2
      exit 127
    fi
  '
}

render_template() {
  local template_path="$1"
  require_command python3
  ENV_FILE="$ENV_FILE" TEMPLATE_PATH="$template_path" python3 - <<'PY'
import os
from pathlib import Path

env = dict(os.environ)
for line in Path(os.environ["ENV_FILE"]).read_text(encoding="utf-8").splitlines():
    if not line.strip() or line.lstrip().startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    env[key.strip()] = value.strip()

body = Path(os.environ["TEMPLATE_PATH"]).read_text(encoding="utf-8")
for key, value in env.items():
    body = body.replace("${" + key + "}", value)
print(body)
PY
}
