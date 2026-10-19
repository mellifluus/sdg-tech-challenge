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

# shellcheck disable=SC2329 # invoked via poll_eq
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
# shellcheck disable=SC2329 # invoked via expect_ok
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
