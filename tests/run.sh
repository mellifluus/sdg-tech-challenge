#!/usr/bin/env bash
# Integration tests for the deployed stack.
# Reads everything from `terraform output`, runs mc / psql in throwaway containers attached to
# the stack network. Requires: docker, terraform, jq, curl. Exit code = number of failed checks.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT_DIR/terraform/platform}"
FIXTURE="$ROOT_DIR/tests/fixtures/orders.csv"
FIXTURE_KEY="fixtures/orders.csv"
E2E_TABLE="e2e_orders"

# CONFIG

out=$(terraform -chdir="$TF_DIR" output -json)
[ "$out" != "{}" ] || { echo "No terraform outputs, run 'make up' first." >&2; exit 1; }
tf() { jq -r "$1" <<<"$out"; }

NETWORK=$(tf .networks.value.data)
MC_IMAGE=$(tf .mc_image.value)
PG_IMAGE=$(tf .postgres_image.value)
MINIO_API=$(tf .minio.value.api_url)
MINIO_CONSOLE=$(tf .minio.value.console_url)
MINIO_INTERNAL=$(tf .minio.value.internal_endpoint)
BUCKET=$(tf '.minio.value.buckets[0]')
PG_HOST=$(tf .postgres.value.internal_host)
ORCH_DB=$(tf .postgres.value.orchestrator_db)
WH_DB=$(tf .postgres.value.warehouse_db)

# mc aliases "root" and "app", passed to the container by env var name only
export MC_HOST_root="${MINIO_INTERNAL/:\/\//://$(tf .minio.value.root_user):$(tf .minio_root_password.value)@}"
export MC_HOST_app="${MINIO_INTERNAL/:\/\//://$(tf .minio.value.app_user):$(tf .minio_app_password.value)@}"

# HELPERS

pass=0
fail=0
c_green=$'\033[32m'; c_red=$'\033[31m'; c_off=$'\033[0m'
[ -t 1 ] || { c_green=; c_red=; c_off=; }

section() { printf '\n== %s\n' "$1"; }
ok()      { pass=$((pass + 1)); printf '  %sPASS%s %s\n' "$c_green" "$c_off" "$1"; }
ko()      { fail=$((fail + 1)); printf '  %sFAIL%s %s\n' "$c_red" "$c_off" "$1"; }

# expect_ok / expect_fail "<description>" cmd...
expect_ok()   { local d=$1; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else ko "$d"; fi; }
expect_fail() { local d=$1; shift; if "$@" >/dev/null 2>&1; then ko "$d"; else ok "$d"; fi; }

# expect_eq "<description>" <expected> <actual>
expect_eq() {
  if [ "$2" = "$3" ]; then ok "$1"; else ko "$1 (expected '$2', got '$3')"; fi
}

mc() {
  docker run --rm -i --network "$NETWORK" -e MC_HOST_root -e MC_HOST_app "$MC_IMAGE" "$@"
}

# psql_as <role> <database> [psql args...]
psql_as() {
  local role=$1 db=$2; shift 2
  PGPASSWORD=$(tf ".postgres_passwords.value[\"$role\"]") \
    docker run --rm -i --network "$NETWORK" -e PGPASSWORD -e PGCONNECT_TIMEOUT=5 "$PG_IMAGE" \
    psql -h "$PG_HOST" -U "$role" -d "$db" -X -q -A -t -v ON_ERROR_STOP=1 "$@"
}

sha() { if command -v sha256sum >/dev/null; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1; }

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

printf '\n%d passed, %d failed\n' "$pass" "$fail"
exit "$fail"
