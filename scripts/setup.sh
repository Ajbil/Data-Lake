#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=linux/common.sh
source "$SCRIPT_DIR/linux/common.sh"

show_help() {
  cat <<'EOF'
MBS Data Lake POC Linux command runner

Usage:
  ./scripts/setup.sh <command>

Commands:
  help              Show this help.
  init              Create .env from .env.example if .env does not exist.
  start             Start Docker Compose services.
  ps                Show Docker service status.
  stop              Stop Docker Compose services without deleting volumes.
  restart:connect   Restart Kafka Connect after plugin installation.

  plugin:avro       Download Confluent Avro converter jars.
  plugin:iceberg    Download Apache Iceberg Kafka Connect sink jars.
  bootstrap:source-login
                    Create local Debezium SQL Server reader login, when using local SQL Server.
  bootstrap:report-sample
                    Create local DSB report sample databases, seed data, and CDC.
  register:source   Register Debezium SQL Server source connector.
  register:raw      Register Iceberg Raw sink connectors.

  health:services   Check Docker services and platform endpoints.
  health:source     Check Debezium, Kafka topics, Schema Registry, MinIO, Iceberg REST.
  health:iceberg    Check Iceberg sink plugin and connector task status.
  health:raw        Confirm Raw Iceberg namespaces and warehouse objects.

  bootstrap:dbt     Install dbt-starrocks dependencies.
  bootstrap:starrocks
                    Create StarRocks external Iceberg catalog.
  health:starrocks  Verify StarRocks can query Raw Iceberg tables.
  run:dbt           Run dbt debug, run, and test.
  health:dbt        Verify Silver/Gold tables in StarRocks.

Typical server flow:
  ./scripts/setup.sh init
  ./scripts/setup.sh start
  ./scripts/setup.sh bootstrap:report-sample
  ./scripts/setup.sh plugin:avro
  ./scripts/setup.sh restart:connect
  ./scripts/setup.sh register:source
  ./scripts/setup.sh health:source
  ./scripts/setup.sh plugin:iceberg
  ./scripts/setup.sh restart:connect
  ./scripts/setup.sh register:raw
  ./scripts/setup.sh health:iceberg
  ./scripts/setup.sh health:raw
EOF
}

bootstrap_day1() {
  require_env_file
  local password
  password="$(read_env MSSQL_SA_PASSWORD)"
  local files=(
    "sql/ddl/001_create_database.sql"
    "sql/ddl/002_create_tables.sql"
    "sql/seed/001_seed_agents.sql"
    "sql/seed/002_seed_kyc_completions.sql"
    "sql/cdc/001_enable_cdc.sql"
    "sql/cdc/002_set_retention_7_days.sql"
  )
  for file in "${files[@]}"; do
    log "Running $file"
    sqlcmd_in_container "$password" < "$REPO_ROOT/$file"
  done
  log "Local SQL Server sample bootstrap complete."
}

bootstrap_day2() {
  require_env_file
  local password
  password="$(read_env MSSQL_SA_PASSWORD)"
  sqlcmd_in_container "$password" < "$REPO_ROOT/sql/security/002_create_debezium_login.sql"
  log "Debezium SQL Server login bootstrap complete."
}

bootstrap_report_sample() {
  require_env_file
  local password
  password="$(read_env MSSQL_SA_PASSWORD)"
  local files=(
    "sql/report_sample/001_create_daily_operations_sample.sql"
    "sql/report_sample/002_seed_daily_operations_sample.sql"
    "sql/report_sample/003_enable_daily_operations_cdc.sql"
    "sql/verification/report_sample_counts.sql"
  )
  for file in "${files[@]}"; do
    log "Running $file"
    sqlcmd_in_container "$password" < "$REPO_ROOT/$file"
  done
  log "Daily Operations Report local SQL Server sample is ready."
}

download_plugin() {
  local name="$1"
  local pom_path="$2"
  local output_dir="$3"
  [[ -f "$REPO_ROOT/$pom_path" ]] || { printf 'Missing plugin pom: %s\n' "$pom_path" >&2; return 1; }
  log "Downloading $name dependencies into $output_dir"
  docker run --rm \
    -v "$REPO_ROOT:/workspace" \
    -w /workspace \
    maven:3.9-eclipse-temurin-17 \
    mvn -q \
    -f "$pom_path" \
    dependency:copy-dependencies \
    "-DoutputDirectory=/workspace/$output_dir" \
    "-DincludeScope=runtime"
}

register_connector() {
  local name="$1"
  local template="$2"
  local tmp
  tmp="$(mktemp)"
  render_template "$REPO_ROOT/$template" > "$tmp"
  log "Registering connector $name"
  curl -fsS -X PUT \
    -H "Content-Type: application/json" \
    --data-binary "@$tmp" \
    "http://localhost:8083/connectors/$name/config"
  rm -f "$tmp"
  printf '\n'
}

register_day2() {
  require_env_file
  export MSSQL_HOST="${MSSQL_HOST:-$(read_env MSSQL_HOST 2>/dev/null || printf 'sqlserver')}"
  export MSSQL_PORT="${MSSQL_PORT:-$(read_env MSSQL_PORT 2>/dev/null || printf '1433')}"
  export MSSQL_CAPTURE_DATABASES="${MSSQL_CAPTURE_DATABASES:-$(read_env MSSQL_CAPTURE_DATABASES 2>/dev/null || printf 'EKYC_ICICI,EKYC_ICICI_Archived')}"
  export KAFKA_TOPIC_PREFIX="${KAFKA_TOPIC_PREFIX:-$(read_env KAFKA_TOPIC_PREFIX 2>/dev/null || printf 'mbs_poc')}"
  register_connector "mbs-sqlserver-cdc" "infra/kafka-connect/connectors/debezium-sqlserver-mbs-poc.template.json"
}

register_day3() {
  require_env_file
  export ICEBERG_CONTROL_TOPIC="${ICEBERG_CONTROL_TOPIC:-$(read_env ICEBERG_CONTROL_TOPIC 2>/dev/null || printf 'mbs_iceberg_control')}"
  curl -fsS http://localhost:8083/connector-plugins | grep -q "org.apache.iceberg.connect.IcebergSinkConnector" || {
    printf 'IcebergSinkConnector is not loaded. Run plugin:iceberg, restart:connect, then retry.\n' >&2
    return 1
  }
  local prefix current_db archived_db
  prefix="$(read_env KAFKA_TOPIC_PREFIX 2>/dev/null || printf 'mbs_poc')"
  current_db="EKYC_ICICI"
  archived_db="EKYC_ICICI_Archived"

  local mappings=(
    "customer-lead|$prefix.$current_db.dbo.Customer_Lead|raw.customer_lead_cdc_connect"
    "customer-lead-icici|$prefix.$current_db.dbo.Customer_Lead_ICICI|raw.customer_lead_icici_cdc_connect"
    "change-pincode-log|$prefix.$current_db.dbo.ChangePincode_log|raw.change_pincode_log_cdc_connect"
    "service-request-assign-log|$prefix.$current_db.dbo.ServiceRequestAssignLog|raw.service_request_assign_log_cdc_connect"
    "sr-status-update-log|$prefix.$current_db.dbo.SRStatusUpdateLog|raw.sr_status_update_log_cdc_connect"
    "mas-pincode|$prefix.$current_db.dbo.MasPincode|raw.mas_pincode_cdc_connect"
    "mas-pincode-mis-hdfc|$prefix.$current_db.dbo.Mas_Pincode_For_MIS_HDFC|raw.mas_pincode_for_mis_hdfc_cdc_connect"
    "mst-campaign-leads|$prefix.$current_db.dbo.MstCampaignLeads|raw.mst_campaign_leads_cdc_connect"
    "mbs-user|$prefix.$current_db.dbo.MBSUser|raw.mbs_user_cdc_connect"
    "customer-lead-archived|$prefix.$archived_db.dbo.Customer_Lead_Archived|raw.customer_lead_archived_cdc_connect"
    "customer-lead-purge-details|$prefix.$archived_db.dbo.Customer_Lead_purge_details|raw.customer_lead_purge_details_cdc_connect"
    "service-request-assign-log-archieved|$prefix.$archived_db.dbo.ServiceRequestAssignLog_archieved|raw.service_request_assign_log_archieved_cdc_connect"
    "service-request-assign-log-purge-details|$prefix.$archived_db.dbo.ServiceRequestAssignLog_purge_details|raw.service_request_assign_log_purge_details_cdc_connect"
    "sr-status-update-log-archieved|$prefix.$archived_db.dbo.SRStatusUpdateLog_archieved|raw.sr_status_update_log_archieved_cdc_connect"
    "sr-status-update-log-purge-details|$prefix.$archived_db.dbo.SRStatusUpdateLog_purge_details|raw.sr_status_update_log_purge_details_cdc_connect"
  )

  local entry suffix topic table tmp
  for entry in "${mappings[@]}"; do
    IFS='|' read -r suffix topic table <<< "$entry"
    tmp="$(mktemp)"
    CONNECT_TOPIC="$topic" ICEBERG_TABLE="$table" render_template "$REPO_ROOT/infra/kafka-connect/connectors/iceberg-dsb-raw-sink.template.json" > "$tmp"
    log "Registering Iceberg sink connector mbs-iceberg-$suffix-raw-sink"
    curl -fsS -X PUT \
      -H "Content-Type: application/json" \
      --data-binary "@$tmp" \
      "http://localhost:8083/connectors/mbs-iceberg-$suffix-raw-sink/config"
    rm -f "$tmp"
    printf '\n'
  done
}

health_day1() {
  require_env_file
  log "Docker Compose services:"
  compose ps
  log "Schema Registry subjects:"
  curl -fsS http://localhost:8081/subjects || true
  log "Kafka Connect connectors:"
  curl -fsS http://localhost:8083/connectors || true
  log "Kafka UI status:"
  curl -fsSI http://localhost:8080 | head -1 || true
  local password
  password="$(read_env MSSQL_SA_PASSWORD)"
  log "SQL Server CDC verification:"
  sqlcmd_in_container "$password" < "$REPO_ROOT/sql/verification/001_verify_day1.sql"
}

health_day2() {
  require_env_file
  local minio_user minio_password
  minio_user="$(read_env MINIO_ROOT_USER)"
  minio_password="$(read_env MINIO_ROOT_PASSWORD)"

  log "Debezium connector status:"
  curl -fsS http://localhost:8083/connectors/mbs-sqlserver-cdc/status
  printf '\n'

  log "Kafka topics:"
  docker exec mbs-kafka kafka-topics --bootstrap-server kafka:9092 --list

  log "Schema Registry subjects:"
  local subjects
  subjects="$(curl -fsS http://localhost:8081/subjects)"
  printf '%s\n' "$subjects"
  [[ "$subjects" != "[]" ]] || { printf 'Schema Registry has no subjects. Avro is not active yet.\n' >&2; return 1; }

  log "MinIO buckets:"
  docker run --rm --network container:mbs-minio --entrypoint /bin/sh minio/mc:latest \
    -c "mc alias set local http://localhost:9000 '$minio_user' '$minio_password' >/dev/null && mc ls local"

  log "Iceberg REST catalog health:"
  curl -fsS http://localhost:8181/v1/config
  printf '\n'

  log "Source CDC, Kafka, Avro, MinIO, and Iceberg REST verification complete."
}

health_iceberg() {
  require_env_file
  log "Checking Kafka Connect Iceberg sink plugin..."
  curl -fsS http://localhost:8083/connector-plugins | grep "org.apache.iceberg.connect.IcebergSinkConnector"

  local connectors=(
    mbs-sqlserver-cdc
    mbs-iceberg-customer-lead-raw-sink
    mbs-iceberg-customer-lead-icici-raw-sink
    mbs-iceberg-change-pincode-log-raw-sink
    mbs-iceberg-service-request-assign-log-raw-sink
    mbs-iceberg-sr-status-update-log-raw-sink
    mbs-iceberg-mas-pincode-raw-sink
    mbs-iceberg-mas-pincode-mis-hdfc-raw-sink
    mbs-iceberg-mst-campaign-leads-raw-sink
    mbs-iceberg-mbs-user-raw-sink
    mbs-iceberg-customer-lead-archived-raw-sink
    mbs-iceberg-customer-lead-purge-details-raw-sink
    mbs-iceberg-service-request-assign-log-archieved-raw-sink
    mbs-iceberg-service-request-assign-log-purge-details-raw-sink
    mbs-iceberg-sr-status-update-log-archieved-raw-sink
    mbs-iceberg-sr-status-update-log-purge-details-raw-sink
  )
  for connector in "${connectors[@]}"; do
    log "Checking $connector status..."
    local status
    status="$(curl -fsS "http://localhost:8083/connectors/$connector/status")"
    printf '%s\n' "$status"
    printf '%s' "$status" | python3 -c 'import json,sys; s=json.load(sys.stdin); tasks=s.get("tasks",[]); sys.exit(0 if s["connector"]["state"]=="RUNNING" and tasks and all(t["state"]=="RUNNING" for t in tasks) else 1)' || {
      printf '%s connector/task is not RUNNING.\n' "$connector" >&2
      return 1
    }
  done
}

health_day3() {
  require_env_file
  local minio_user minio_password minio_bucket
  minio_user="$(read_env MINIO_ROOT_USER)"
  minio_password="$(read_env MINIO_ROOT_PASSWORD)"
  minio_bucket="$(read_env MINIO_BUCKET)"

  log "Waiting for Kafka Connect Iceberg commit interval..."
  sleep 45
  health_iceberg

  log "MinIO Raw warehouse objects:"
  docker run --rm --network container:mbs-minio --entrypoint /bin/sh minio/mc:latest \
    -c "mc alias set local http://localhost:9000 '$minio_user' '$minio_password' >/dev/null && mc ls --recursive 'local/$minio_bucket/warehouse/raw' | tail -40"

  log "Raw Iceberg verification complete."
}

bootstrap_day3_python() {
  require_command python3
  [[ -f "$REPO_ROOT/requirements-day3.txt" ]] || { printf 'Missing requirements-day3.txt\n' >&2; return 1; }
  if [[ ! -x "$REPO_ROOT/.venv/bin/python" ]]; then
    python3 -m venv "$REPO_ROOT/.venv"
  fi
  "$REPO_ROOT/.venv/bin/python" -m pip install --upgrade pip
  "$REPO_ROOT/.venv/bin/python" -m pip install -r "$REPO_ROOT/requirements-day3.txt"
  log "Python environment is ready at .venv."
}

bootstrap_starrocks() {
  require_env_file
  local tmp
  tmp="$(mktemp)"
  render_template "$REPO_ROOT/infra/starrocks/catalogs/create_iceberg_catalog.sql" > "$tmp"
  docker exec -i mbs-starrocks-fe bash -lc "mysql -h 127.0.0.1 -P 9030 -u root" < "$tmp"
  rm -f "$tmp"
  log "StarRocks Iceberg catalog bootstrap complete."
}

health_starrocks() {
  docker exec mbs-starrocks-fe bash -lc "mysql -h 127.0.0.1 -P 9030 -u root -e 'SHOW FRONTENDS; SHOW BACKENDS;'"
  docker exec -i mbs-starrocks-fe bash -lc "mysql -h 127.0.0.1 -P 9030 -u root" < "$REPO_ROOT/sql/verification/day4_starrocks_raw_counts.sql"
  log "StarRocks + Iceberg verification complete."
}

bootstrap_dbt() {
  [[ -x "$REPO_ROOT/.venv/bin/python" ]] || bootstrap_day3_python
  "$REPO_ROOT/.venv/bin/python" -m pip install -r "$REPO_ROOT/requirements-day4.txt"
  log "dbt dependencies are ready."
}

run_dbt() {
  load_env_exports
  [[ -x "$REPO_ROOT/.venv/bin/dbt" ]] || { printf 'dbt is not installed. Run ./scripts/setup.sh bootstrap:dbt first.\n' >&2; return 1; }
  export DBT_PROFILES_DIR="$REPO_ROOT/dbt"
  export STARROCKS_DBT_HOST="${STARROCKS_DBT_HOST:-127.0.0.1}"
  export STARROCKS_MYSQL_PORT="${STARROCKS_MYSQL_PORT:-9030}"
  export STARROCKS_CATALOG="${STARROCKS_CATALOG:-default_catalog}"
  export STARROCKS_SCHEMA="${STARROCKS_SCHEMA:-analytics}"
  export STARROCKS_USER="${STARROCKS_USER:-root}"
  export STARROCKS_PASSWORD="${STARROCKS_PASSWORD:-}"
  "$REPO_ROOT/.venv/bin/dbt" debug --project-dir "$REPO_ROOT/dbt" --target "${DBT_TARGET:-dev}"
  "$REPO_ROOT/.venv/bin/dbt" run --project-dir "$REPO_ROOT/dbt" --target "${DBT_TARGET:-dev}"
  "$REPO_ROOT/.venv/bin/dbt" test --project-dir "$REPO_ROOT/dbt" --target "${DBT_TARGET:-dev}"
}

health_dbt() {
  docker exec -i mbs-starrocks-fe bash -lc "mysql -h 127.0.0.1 -P 9030 -u root" <<'SQL'
SELECT COUNT(*) AS silver_customer_leads_count FROM default_catalog.analytics.silver_customer_lead_consolidated;
SELECT COUNT(*) AS silver_assignment_log_count FROM default_catalog.analytics.silver_service_request_assign_log_consolidated;
SELECT COUNT(*) AS silver_sr_status_log_count FROM default_catalog.analytics.silver_sr_status_update_log_consolidated;
SELECT COUNT(*) AS silver_mbs_user_count FROM default_catalog.analytics.silver_mbs_user;
SELECT COUNT(*) AS gold_daily_operations_report_count FROM default_catalog.analytics.gold_daily_operations_report;
SELECT record_type, COUNT(*) AS lead_count
FROM default_catalog.analytics.gold_daily_operations_report
GROUP BY record_type
ORDER BY record_type;
SQL
  log "Daily Operations Report dbt verification complete."
}

cd "$REPO_ROOT"

command_name="${1:-help}"
case "$command_name" in
  help) show_help ;;
  init)
    if [[ -f "$ENV_FILE" ]]; then
      log ".env already exists; leaving it unchanged."
    else
      cp "$ENV_EXAMPLE" "$ENV_FILE"
      log "Created .env from .env.example."
    fi
    ;;
  start)
    catalog_name="$(docker ps -a --filter 'name=^/mbs-iceberg-rest$' --format '{{.Names}}')"
    if [[ -n "$catalog_name" ]]; then
      catalog_mounts="$(docker inspect --format '{{range .Mounts}}{{println .Destination}}{{end}}' mbs-iceberg-rest)"
      if ! grep -Fxq '/catalog' <<< "$catalog_mounts"; then
        echo 'Existing Iceberg catalog needs backup and storage migration before startup. See docs/runbooks/02_poc_execution.md.' >&2
        exit 1
      fi
    fi
    kafka_name="$(docker ps -a --filter 'name=^/mbs-kafka$' --format '{{.Names}}')"
    if [[ -n "$kafka_name" ]]; then
      kafka_log_dir="$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' mbs-kafka | sed -n 's/^KAFKA_LOG_DIRS=//p')"
      kafka_mount="$(docker inspect --format '{{range .Mounts}}{{if eq .Name "mbs-poc_kafka-data"}}{{println .Destination}}{{end}}{{end}}' mbs-kafka)"
      if [[ -z "$kafka_log_dir" || "$kafka_log_dir" != "$kafka_mount" ]]; then
        echo 'Kafka logs need preserved migration into the named volume before startup. See docs/decisions/007_kafka_log_storage.md.' >&2
        exit 1
      fi
    fi
    compose up -d
    ;;
  ps) compose ps ;;
  stop) compose stop ;;
  restart:connect) docker restart mbs-kafka-connect ;;
  bootstrap:local-sql|bootstrap:day1) bootstrap_day1 ;;
  bootstrap:source-login|bootstrap:day2) bootstrap_day2 ;;
  bootstrap:report-sample) bootstrap_report_sample ;;
  plugin:avro) download_plugin "Confluent Avro converter" "infra/kafka-connect/plugins/avro-converter/pom.xml" "infra/kafka-connect/plugins/avro-converter" ;;
  plugin:iceberg) download_plugin "Apache Iceberg Kafka Connect sink" "infra/kafka-connect/plugins/iceberg-sink/pom.xml" "infra/kafka-connect/plugins/iceberg-sink" ;;
  register:source|register:day2) register_day2 ;;
  register:raw|register:day3) register_day3 ;;
  health:services|health:day1) health_day1 ;;
  health:source|health:day2) health_day2 ;;
  health:iceberg) health_iceberg ;;
  health:raw|health:day3) health_day3 ;;
  bootstrap:python|bootstrap:day3) bootstrap_day3_python ;;
  bootstrap:starrocks|bootstrap:day4-starrocks) bootstrap_starrocks ;;
  health:starrocks|health:day4-starrocks) health_starrocks ;;
  bootstrap:dbt|bootstrap:day4-dbt) bootstrap_dbt ;;
  run:dbt|run:day4-dbt) run_dbt ;;
  health:dbt|health:day4-dbt) health_dbt ;;
  *)
    show_help
    printf 'Unknown command: %s\n' "$command_name" >&2
    exit 1
    ;;
esac
