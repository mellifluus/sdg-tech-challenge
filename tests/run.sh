#!/usr/bin/env bash
# Integration tests for the deployed stack.
# Exit code = number of failed checks. Config and helpers live in lib.sh.
set -euo pipefail

# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FIXTURE="$ROOT_DIR/tests/fixtures/orders.csv"
FIXTURE_KEY="fixtures/orders.csv"
E2E_TABLE="e2e_orders"

# MINIO

section "MinIO"
expect_ok "API health ($MINIO_API)" \
  curl -fsS --retry 5 --retry-connrefused --retry-delay 2 "$MINIO_API/minio/health/ready"
expect_ok "Console reachable ($MINIO_CONSOLE)" \
  curl -fsS --retry 5 --retry-connrefused --retry-delay 2 "$MINIO_CONSOLE/"

expect_ok "bucket '$BUCKET' exists" mc stat "root/$BUCKET"
expect_eq "bucket '$BUCKET' versioning" "Enabled" \
  "$(mc version info "root/$BUCKET" --json 2>/dev/null | jq -r .versioning.status)"

expect_ok "app user uploads fixture to $BUCKET/$FIXTURE_KEY" \
  mc pipe "app/$BUCKET/$FIXTURE_KEY" <"$FIXTURE"
expect_eq "fixture in bucket matches local file (sha256, read as root)" \
  "$(sha <"$FIXTURE")" "$(mc cat "root/$BUCKET/$FIXTURE_KEY" 2>/dev/null | sha)"

denied_bucket="e2e-denied-$$"
expect_fail "app user cannot create buckets" mc mb "app/$denied_bucket"
mc rb --force "root/$denied_bucket" >/dev/null 2>&1 || true   # cleanup if the check above failed
expect_fail "app user cannot run admin operations" mc admin user list app

# POSTGRESQL

section "PostgreSQL"
expect_ok "server accepts connections" \
  docker run --rm --network "$NETWORK" "$PG_IMAGE" pg_isready -h "$PG_HOST" -t 10

for role in "$ORCH_DB" "$WH_DB"; do
  for db in "$ORCH_DB" "$WH_DB"; do
    if [ "$role" = "$db" ]; then
      expect_ok   "role '$role' can connect to '$db'"    psql_as "$role" "$db" -c 'SELECT 1'
    else
      expect_fail "role '$role' cannot connect to '$db'" psql_as "$role" "$db" -c 'SELECT 1'
    fi
  done
done

# PROMETHEUS

section "Prometheus"
expect_ok "ready ($PROMETHEUS)" \
  curl -fsS --retry 5 --retry-connrefused --retry-delay 2 "$PROMETHEUS/-/ready"

# shellcheck disable=SC2317,SC2329 # invoked via poll_eq
down_targets() {
  curl -fsS "$PROMETHEUS/api/v1/targets?state=active" |
    jq -r '[.data.activeTargets[] | select(.health != "up") | .labels.job] | join(",")'
}
poll_eq "all scrape targets up" "" down_targets
poll_eq "exporter connected to PostgreSQL (pg_up)" "1" prom_query 'pg_up'
poll_eq "MinIO reports online nodes" "1" prom_query 'minio_cluster_nodes_online_total'
expect_fail "monitoring network cannot reach PostgreSQL directly" \
  docker run --rm --network "$MON_NETWORK" "$PG_IMAGE" pg_isready -h "$PG_HOST" -t 3

# GRAFANA

section "Grafana"
expect_ok "healthy ($GRAFANA)" \
  curl -fsS --retry 5 --retry-connrefused --retry-delay 2 "$GRAFANA/api/health"
expect_eq "anonymous API access rejected" "401" \
  "$(curl -sS -o /dev/null -w '%{http_code}' "$GRAFANA/api/search")"
expect_eq "Prometheus datasource healthy" "OK" \
  "$(grafana_api /api/datasources/uid/prometheus/health | jq -r .status)"
expect_eq "dashboard '$GRAFANA_DASHBOARD' provisioned" "true" \
  "$(grafana_api "/api/dashboards/uid/$GRAFANA_DASHBOARD" | jq -r .meta.provisioned)"
expect_eq "alert rules provisioned (one per rule in grafana-alerts.yml)" "$GRAFANA_ALERT_RULES" \
  "$(grafana_api /api/v1/provisioning/alert-rules | jq '[.[] | select(.uid | startswith("sdg-"))] | length')"

# AIRFLOW

section "Airflow"
expect_ok "api-server healthy ($AIRFLOW)" \
  curl -fsS --retry 5 --retry-connrefused --retry-delay 2 "$AIRFLOW/api/v2/monitor/health"
# Heartbeats can lag right after `make up`, so poll.
poll_eq "metadata database healthy" "healthy" airflow_health metadatabase
poll_eq "scheduler healthy" "healthy" airflow_health scheduler
poll_eq "dag-processor healthy" "healthy" airflow_health dag_processor
expect_eq "anonymous API access rejected" "401" \
  "$(curl -sS -o /dev/null -w '%{http_code}' "$AIRFLOW/api/v2/dags")"

token=$(airflow_token "$AIRFLOW_USER" "$AIRFLOW_PASSWORD")
expect_ok "admin user '$AIRFLOW_USER' gets an API token" test -n "$token"
expect_eq "API accepts the admin token" "200" \
  "$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $token" "$AIRFLOW/api/v2/dags")"

# DAGs are parsed asynchronously by the dag-processor (refresh every 30s), so poll.
section "Airflow DAGs"
# Convention: each top-level file in dags/ defines one DAG named after the file.
# shellcheck disable=SC2317,SC2329 # invoked via poll_eq
dag_status() { airflow_api "$token" "/api/v2/dags/$1" | jq -r '"stale=\(.is_stale) paused=\(.is_paused)"'; }
for f in "$AIRFLOW_DAGS_DIR"/*.py; do
  dag=$(basename "$f" .py)
  POLL_TRIES=45 poll_eq "DAG '$dag' registered and unpaused" "stale=false paused=false" dag_status "$dag"
done
# Checked after registration: before the first parse there are no errors to report yet.
expect_eq "no DAG import errors" "" \
  "$(airflow_api "$token" /api/v2/importErrors | jq -r '.import_errors | map(.filename) | join(",")')"

# E2E: ingest_orders (MinIO -> Airflow -> PostgreSQL)

section "E2E (ingest_orders)"
# One valid file and two invalid ones: a wrong header, and a valid row followed by a price with
# 3 decimals (checks the file is rejected as a whole, with no partial load).
tag="e2e-$(date +%s)"
GOOD="$tag-good.csv"
BAD_HEADER="$tag-bad-header.csv"
BAD_ROW="$tag-bad-row.csv"
t0=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Upload the bad files first: if the DAG lists the prefix between uploads, at least the good
# file still lands in a later run.
expect_ok "upload '$BAD_HEADER' to raw/orders/" mc pipe "app/$BUCKET/raw/orders/$BAD_HEADER" <<'CSV'
id,date,customer
1,2026-01-01,acme
CSV
expect_ok "upload '$BAD_ROW' to raw/orders/" mc pipe "app/$BUCKET/raw/orders/$BAD_ROW" <<'CSV'
order_id,order_date,customer,product,quantity,unit_price
9001,2026-01-01,acme,widget,1,9.99
9002,2026-01-02,acme,widget,1,9.999
CSV
expect_ok "upload '$GOOD' to raw/orders/" mc pipe "app/$BUCKET/raw/orders/$GOOD" <"$FIXTURE"

# The DAG runs every 15 min and its sensor may already be waiting, so the files can be picked up
# by a scheduled run instead of this one (max_active_runs=1). The checks below therefore look at
# the outcome (where files end up, what is in the table), not at a specific run.
run_id=$(airflow_api "$token" /api/v2/dags/ingest_orders/dagRuns -X POST -d '{"logical_date": null}' |
  jq -r '.dag_run_id // empty')
expect_ok "trigger 'ingest_orders'" test -n "$run_id"

# shellcheck disable=SC2317,SC2329 # invoked via poll_eq
file_prefix() {
  local p
  for p in processed rejected raw; do
    if mc stat "root/$BUCKET/$p/orders/$1" >/dev/null 2>&1; then echo "$p"; return; fi
  done
}
# Sensor poke + mapped tasks usually take under a minute; allow ~3 min for a cold scheduler.
POLL_TRIES=90 poll_eq "'$GOOD' moved to processed/" "processed" file_prefix "$GOOD"
POLL_TRIES=30 poll_eq "'$BAD_HEADER' moved to rejected/" "rejected" file_prefix "$BAD_HEADER"
POLL_TRIES=30 poll_eq "'$BAD_ROW' moved to rejected/" "rejected" file_prefix "$BAD_ROW"

loaded() {
  psql_as "$WH_DB" "$WH_DB" -c "SELECT count(*), coalesce(sum(quantity * unit_price), 0)
    FROM staging.orders WHERE source_file = 'raw/orders/$1'" 2>/dev/null || true
}
expected=$(awk -F, 'NR > 1 { n++; t += $5 * $6 } END { printf "%d|%.2f", n, t }' "$FIXTURE")
expect_eq "staging.orders rows from '$GOOD' match fixture (count|sum)" "$expected" "$(loaded "$GOOD")"
expect_eq "no rows loaded from '$BAD_ROW'" "0|0" "$(loaded "$BAD_ROW")"

# check_rejections fails the run after all files are processed, which is what alerts on rejections.
# shellcheck disable=SC2317,SC2329 # invoked via poll_eq
failed_runs() {
  airflow_api "$token" "/api/v2/dags/ingest_orders/dagRuns?state=failed&end_date_gte=$t0" |
    jq -r '.total_entries > 0'
}
POLL_TRIES=30 poll_eq "rejections fail the 'ingest_orders' run" "true" failed_runs

mc rm "root/$BUCKET/processed/orders/$GOOD" "root/$BUCKET/rejected/orders/$BAD_HEADER" \
  "root/$BUCKET/rejected/orders/$BAD_ROW" >/dev/null 2>&1 || true

# E2E: bucket -> warehouse

section "E2E (MinIO -> PostgreSQL)"
expect_ok "create table '$E2E_TABLE' if missing" psql_as "$WH_DB" "$WH_DB" -c "
  CREATE TABLE IF NOT EXISTS $E2E_TABLE (
    order_id   integer PRIMARY KEY,
    order_date date          NOT NULL,
    customer   text          NOT NULL,
    product    text          NOT NULL,
    quantity   integer       NOT NULL,
    unit_price numeric(10,2) NOT NULL
  )"

# Truncate + load in one transaction, so re-runs are idempotent.
# shellcheck disable=SC2317,SC2329 # invoked via expect_ok
load() {
  mc cat "app/$BUCKET/$FIXTURE_KEY" | psql_as "$WH_DB" "$WH_DB" -1 \
    -c "TRUNCATE $E2E_TABLE" \
    -c "\\copy $E2E_TABLE FROM pstdin WITH (FORMAT csv, HEADER true)"
}
expect_ok "stream fixture from bucket into '$E2E_TABLE'" load

expected=$(awk -F, 'NR > 1 { n++; t += $5 * $6 } END { printf "%d|%.2f", n, t }' "$FIXTURE")
actual=$(psql_as "$WH_DB" "$WH_DB" -c "SELECT count(*), sum(quantity * unit_price) FROM $E2E_TABLE" 2>/dev/null || true)
expect_eq "table rows and total match fixture (count|sum)" "$expected" "$actual"

# SUMMARY

summary
