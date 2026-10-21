# shellcheck shell=bash disable=SC2034,SC2317,SC2329 # library: vars and functions are used by the sourcing scripts
# Shared config and helpers for the test scripts. Source it, don't run it.
# Reads everything from `terraform output`, runs mc / psql in throwaway containers attached to
# the stack network. Requires: docker, terraform, jq, curl.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT_DIR/terraform/platform}"

# CONFIG

out=$(terraform -chdir="$TF_DIR" output -json)
[ "$out" != "{}" ] || { echo "No terraform outputs, run 'make up' first." >&2; exit 1; }
tf() { jq -r "$1" <<<"$out"; }

NETWORK=$(tf .networks.value.data)
MON_NETWORK=$(tf .networks.value.monitoring)
MC_IMAGE=$(tf .mc_image.value)
PG_IMAGE=$(tf .postgres_image.value)
MINIO_API=$(tf .minio.value.api_url)
MINIO_CONSOLE=$(tf .minio.value.console_url)
MINIO_INTERNAL=$(tf .minio.value.internal_endpoint)
BUCKET=$(tf '.minio.value.buckets[0]')
PG_HOST=$(tf .postgres.value.internal_host)
ORCH_DB=$(tf .postgres.value.orchestrator_db)
WH_DB=$(tf .postgres.value.warehouse_db)
PROMETHEUS=$(tf .monitoring.value.prometheus_url)
GRAFANA=$(tf .monitoring.value.grafana_url)
GRAFANA_AUTH="$(tf .monitoring.value.grafana_user):$(tf .grafana_admin_password.value)"
GRAFANA_DASHBOARD="sdg-platform-overview"
GRAFANA_ALERT_RULES=$(grep -c '^ *- uid: sdg-' "$ROOT_DIR/terraform/modules/monitoring/grafana/grafana-alerts.yml")
AIRFLOW=$(tf .airflow.value.url)
AIRFLOW_USER=$(tf .airflow.value.admin_user)
AIRFLOW_PASSWORD=$(tf .airflow_admin_password.value)

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

# prom_query <promql>: first sample value, empty if no result
prom_query() {
  curl -fsS "$PROMETHEUS/api/v1/query" --data-urlencode "query=$1" 2>/dev/null |
    jq -r '.data.result[0].value[1] // empty'
}

# prom_query_at <promql> <unix time>: like prom_query, evaluated at a past instant
prom_query_at() {
  curl -fsS "$PROMETHEUS/api/v1/query" --data-urlencode "query=$1" --data-urlencode "time=$2" 2>/dev/null |
    jq -r '.data.result[0].value[1] // empty'
}

# poll_eq "<description>" <expected> cmd...: retries cmd for ~60s (first scrape may be pending)
poll_eq() {
  local d=$1 want=$2 got=; shift 2
  for _ in $(seq 30); do
    got=$("$@" || true)
    [ "$got" = "$want" ] && break
    sleep 2
  done
  expect_eq "$d" "$want" "$got"
}

# summary: prints the totals and exits with the number of failed checks
summary() { printf '\n%d passed, %d failed\n' "$pass" "$fail"; exit "$fail"; }

sha() { if command -v sha256sum >/dev/null; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1; }

# grafana_api <path>: authenticated GET as the admin user
grafana_api() { curl -fsS -u "$GRAFANA_AUTH" "$GRAFANA$1" 2>/dev/null; }

# airflow_health <component>: status reported by the api-server (metadatabase, scheduler, dag_processor...)
airflow_health() { curl -fsS "$AIRFLOW/api/v2/monitor/health" 2>/dev/null | jq -r ".$1.status"; }

# airflow_token <user> <password>: JWT from the simple auth manager, empty if login fails
airflow_token() {
  jq -n --arg u "$1" --arg p "$2" '{username: $u, password: $p}' |
    curl -fsS -X POST "$AIRFLOW/auth/token" -H 'Content-Type: application/json' -d @- 2>/dev/null |
    jq -r '.access_token // empty'
}
