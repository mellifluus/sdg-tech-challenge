#!/usr/bin/env bash
# Persistence test: writes a marker into every stateful service, destroys and recreates the
# platform layer (containers only, foundation volumes are kept), then checks the markers survived.
# Destructive for running containers, so it is not part of `make test`.
# Exit code = number of failed checks. Config and helpers live in lib.sh.
set -euo pipefail

# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MARKER="persist-$(date +%s)-$$"
MARKER_KEY="persistence/marker.txt"
MARKER_TABLE="persistence_check"
MARKER_TAG="persistence-test"

stack_containers() {
  { docker ps -q --filter "network=$NETWORK"; docker ps -q --filter "network=$MON_NETWORK"; } | sort -u
}

# WRITE MARKERS

section "Write markers"
expect_ok "MinIO: app user uploads $BUCKET/$MARKER_KEY" \
  mc pipe "app/$BUCKET/$MARKER_KEY" <<<"$MARKER"
expect_ok "PostgreSQL: insert marker into '$MARKER_TABLE'" psql_as "$WH_DB" "$WH_DB" \
  -c "CREATE TABLE IF NOT EXISTS $MARKER_TABLE (marker text PRIMARY KEY)" \
  -c "INSERT INTO $MARKER_TABLE VALUES ('$MARKER')"
expect_ok "Grafana: create annotation tagged '$MARKER_TAG'" \
  curl -fsS -u "$GRAFANA_AUTH" -H 'Content-Type: application/json' "$GRAFANA/api/annotations" \
  -d "{\"text\": \"$MARKER\", \"tags\": [\"$MARKER_TAG\"]}"
# Prometheus already holds scraped samples at this instant; they must still be queryable later.
t0=$(date +%s)
expect_ok "Prometheus: has samples at t0" test -n "$(prom_query_at 'count(up)' "$t0")"

before=$(stack_containers)

# RECREATE

section "Recreate platform layer"
expect_ok "make down" make -C "$ROOT_DIR" down
expect_eq "no stack containers left" "" "$(stack_containers)"
for vol in $(tf '.volumes.value[]'); do
  expect_ok "volume '$vol' kept" docker volume inspect "$vol"
done
expect_ok "make up" make -C "$ROOT_DIR" up
after=$(stack_containers)
expect_eq "every container is new" "" "$(comm -12 <(echo "$before") <(echo "$after"))"

# VERIFY MARKERS

section "Verify markers"
expect_eq "MinIO: object content survived" "$MARKER" \
  "$(mc cat "root/$BUCKET/$MARKER_KEY" 2>/dev/null || true)"
expect_eq "PostgreSQL: row survived" "$MARKER" \
  "$(psql_as "$WH_DB" "$WH_DB" -c "SELECT marker FROM $MARKER_TABLE WHERE marker = '$MARKER'" 2>/dev/null || true)"
expect_eq "Grafana: annotation survived" "$MARKER" \
  "$(grafana_api "/api/annotations?tags=$MARKER_TAG&limit=100" |
     jq -r --arg m "$MARKER" '.[] | select(.text == $m) | .text')"
expect_ok "Prometheus: ready" \
  curl -fsS --retry 10 --retry-connrefused --retry-delay 2 "$PROMETHEUS/-/ready"
expect_ok "Prometheus: samples at t0 survived" test -n "$(prom_query_at 'count(up)' "$t0")"

# CLEANUP

mc rm --recursive --versions --force "root/$BUCKET/persistence/" >/dev/null 2>&1 || true
psql_as "$WH_DB" "$WH_DB" -c "DROP TABLE IF EXISTS $MARKER_TABLE" >/dev/null 2>&1 || true
for id in $(grafana_api "/api/annotations?tags=$MARKER_TAG&limit=100" | jq -r '.[].id'); do
  curl -fsS -u "$GRAFANA_AUTH" -X DELETE "$GRAFANA/api/annotations/$id" >/dev/null 2>&1 || true
done

summary
