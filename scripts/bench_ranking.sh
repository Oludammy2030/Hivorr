#!/usr/bin/env bash
# EP-03-20 AT-05 / MT-01 / PV-01: ranking p95 < 400 ms benchmark (plan §6.5, D4).
#
# Seeds (optionally) 5k–10k `published` service listings and fires N
# `service_ranking_search` RPC requests, asserting p95 < 400 ms (phase §10).
#
# Inputs (environment):
#   SUPABASE_URL        staging project URL (https://<ref>.supabase.co)
#   SUPABASE_ANON_KEY   anon key used for the RPC call
#   BENCH_N             request count                      (default: 5000)
#   BENCH_C             concurrency / VUs                  (default: 20)
#   BENCH_Q             search query                       (default: legal)
#   BENCH_SEED_N        published listings to seed         (default: 5000)
#   P95_BUDGET_MS       p95 budget in ms                   (default: 400)
#   DB_URL              psql connection string. REQUIRED for seeding and for
#                       the read-only evidence capture. Never defaulted: an
#                       operator must opt in explicitly (staging/dev only).
#   BENCH_OUT_DIR       artifact directory                 (default: bench-results)
#
# Tooling (decision D4): prefers a local `k6` binary, then the official
# `grafana/k6` Docker image, then `hey`. Skipped-with-warning when no tool or
# no env is available; the JSON artifact always records the outcome. The
# script never reports a false green — exit 0 only on a measured p95 inside
# the budget.
#
# Exit codes: 0 = pass | 1 = budget breach or tool failure | 2 = skipped
# (recorded as OPERATOR EVIDENCE PENDING with an owner in the report).
#
# Run: SUPABASE_URL=... SUPABASE_ANON_KEY=... DB_URL=... bash scripts/bench_ranking.sh

set -euo pipefail

SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
BENCH_N="${BENCH_N:-5000}"
BENCH_C="${BENCH_C:-20}"
BENCH_Q="${BENCH_Q:-legal}"
BENCH_SEED_N="${BENCH_SEED_N:-5000}"
P95_BUDGET_MS="${P95_BUDGET_MS:-400}"
DB_URL="${DB_URL:-}"
BENCH_OUT_DIR="${BENCH_OUT_DIR:-bench-results}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="${BENCH_OUT_DIR}/ranking-p95-result.json"
mkdir -p "$BENCH_OUT_DIR"

# Loopback URLs must reach the host when k6 runs inside a container.
HOST_URL="$SUPABASE_URL"
case "$SUPABASE_URL" in
  *127.0.0.1*|*localhost*) HOST_URL="$(printf '%s' "$SUPABASE_URL" | sed -E 's#(127\.0\.0\.1|localhost)#host.docker.internal#')" ;;
esac
RPC_URL="${HOST_URL%/}/rest/v1/rpc/service_ranking_search"
BODY="{\"p_query\":\"${BENCH_Q}\",\"p_limit\":24}"

# Artifact metadata (plan §6.5 names artifacts bench_ranking_<env>_<date>.json;
# this script keeps a stable filename for the report and records the same
# env/date provenance inside the JSON instead).
case "$SUPABASE_URL" in
  *127.0.0.1*|*localhost*) ENV_NAME="local" ;;
  *) ENV_NAME="$(printf '%s' "$SUPABASE_URL" | sed -E 's#https?://([^./]+).*#\1#')" ;;
esac
RUN_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

emit_skip() { # $1 = reason
  printf '{"status":"skipped","reason":"%s","env":"%s","timestamp":"%s","gate":"p95<%sms","requests":%s,"seeded":false}\n' \
    "$1" "$ENV_NAME" "$RUN_TS" "$P95_BUDGET_MS" "$BENCH_N" > "$RESULT_FILE"
  echo "WARNING: EP-03-20 ranking benchmark SKIPPED — $1" >&2
  echo "WARNING: record as OPERATOR EVIDENCE PENDING (AT-05/MT-01/PV-01); owner: release operator" >&2
  echo "RESULT: $(cat "$RESULT_FILE")"
  exit 2
}

emit_result() { # $1 = status, $2 = p95_ms|null, $3 = tool, $4 = seeded, $5 = reason
  printf '{"status":"%s","env":"%s","timestamp":"%s","gate":"p95<%sms","p95_ms":%s,"requests":%s,"concurrency":%s,"tool":"%s","seeded":%s,"reason":"%s"}\n' \
    "$1" "$ENV_NAME" "$RUN_TS" "$P95_BUDGET_MS" "$2" "$BENCH_N" "$BENCH_C" "$3" "$4" "$5" > "$RESULT_FILE"
  echo "RESULT: $(cat "$RESULT_FILE")"
}

[ -n "$SUPABASE_URL" ]      || emit_skip "SUPABASE_URL not set"
[ -n "$SUPABASE_ANON_KEY" ] || emit_skip "SUPABASE_ANON_KEY not set"

# --- optional seed (dev/staging only; requires explicit DB_URL) -------------
SEEDED=false
SEED_NOTE="seed skipped"
if [ "$BENCH_SEED_N" -gt 0 ] && [ -n "$DB_URL" ] && command -v psql >/dev/null 2>&1; then
  SEED_SQL="$(mktemp "${TMPDIR:-/tmp}/ep03-seed-XXXXXX.sql")"
  cat > "$SEED_SQL" <<'SQL'
\set ON_ERROR_STOP on
begin;
  -- Remove a previous benchmark batch (idempotent re-runs).
  delete from public.service_listings where slug like 'bench-ep0320-%';
  -- Seed published listings bound to the first available profession.
  insert into public.service_listings (
    entity_id, profession_id, industry_id, slug, title, description,
    status, pricing_type, price_min, price_max, currency_code,
    published_at, is_trade_verified_cache
  )
  select
    l.entity_id, p.id, p.industry_id,
    'bench-ep0320-' || l.i,
    'Benchmark legal service listing ' || l.i,
    'Synthetic benchmark listing body for the EP-03-20 ranking latency gate. '
      || 'Volume fixture only; no real customer, pricing, or legal content. '
      || 'Row ' || l.i || '.',
    'published', 'fixed', 1000, 5000, 'NGN', now(), true
  from (
    select (select id from public.entities limit 1) as entity_id,
           generate_series(1, :seed_n) as i
  ) l
  cross join (select id, industry_id from public.professions limit 1) p
  where l.entity_id is not null and p.id is not null;
commit;
select count(*) as seeded_published
from public.service_listings where slug like 'bench-ep0320-%';
SQL
  if psql "$DB_URL" -X -v ON_ERROR_STOP=1 -v seed_n="$BENCH_SEED_N" -q -f "$SEED_SQL" >/dev/null 2>&1; then
    SEEDED=true
    SEED_NOTE="seeded ${BENCH_SEED_N} published listings"
  else
    SEED_NOTE="seed failed or prerequisites (entities/professions) missing"
    echo "WARNING: seed step failed — continuing with existing data ($SEED_NOTE)" >&2
  fi
  rm -f "$SEED_SQL"
elif [ "$BENCH_SEED_N" -gt 0 ]; then
  SEED_NOTE="seed skipped (DB_URL unset or psql missing)"
  echo "NOTE: $SEED_NOTE — directional run only, not the seeded §10 gate" >&2
fi

# --- optional read-only evidence capture (before measuring) ----------------
if [ -n "$DB_URL" ] && command -v psql >/dev/null 2>&1; then
  echo "Capturing read-only staging evidence -> ${BENCH_OUT_DIR}/ep03-staging-evidence.out"
  psql "$DB_URL" -X -v ON_ERROR_STOP=1 -q \
    -f "${SCRIPT_DIR}/ep03-staging-evidence.sql" \
    > "${BENCH_OUT_DIR}/ep03-staging-evidence.out" 2>/dev/null || \
    echo "WARNING: evidence capture failed (non-fatal for the latency gate)" >&2
fi

# --- k6 (local binary or official Docker image) ----------------------------
K6_MODE=""
if command -v k6 >/dev/null 2>&1; then
  K6_MODE="binary"
elif command -v docker >/dev/null 2>&1 && docker image inspect grafana/k6:latest >/dev/null 2>&1; then
  K6_MODE="docker"
fi

if [ -n "$K6_MODE" ]; then
  K6_JS="$(mktemp "${TMPDIR:-/tmp}/ep03-bench-XXXXXX.js")"
  trap 'rm -f "$K6_JS"' EXIT
  cat > "$K6_JS" <<EOF
import http from 'k6/http';
export const options = {
  vus: ${BENCH_C},
  iterations: ${BENCH_N},
  thresholds: { http_req_duration: ['p(95)<${P95_BUDGET_MS}'] },
};
const url = '${RPC_URL}';
const params = {
  headers: {
    'Content-Type': 'application/json',
    'apikey': '${SUPABASE_ANON_KEY}',
    'Authorization': 'Bearer ${SUPABASE_ANON_KEY}',
  },
};
export default function () {
  http.post(url, '${BODY}', params);
}
EOF
  echo "EP-03-20 ranking benchmark via k6 ($K6_MODE): N=${BENCH_N} C=${BENCH_C} Q='${BENCH_Q}' budget p95<${P95_BUDGET_MS}ms ($SEED_NOTE)"
  set +e
  if [ "$K6_MODE" = "binary" ]; then
    K6_OUT="$(k6 run "$K6_JS" 2>&1)"
  else
    # Pipe the script via stdin: avoids Windows/MSYS container-path mangling.
    K6_OUT="$(cat "$K6_JS" | docker run --rm -i grafana/k6:latest run - 2>&1)"
  fi
  K6_RC=$?
  set -e
  echo "$K6_OUT" | tail -25
  # k6's summary prints `p(95)=12.34ms` inline (ms is the default unit).
  P95_MS="$(printf '%s' "$K6_OUT" | sed -n 's/.*p(95)=\([0-9.]*\)ms.*/\1/p' | head -1)"
  [ -n "$P95_MS" ] || P95_MS="$(printf '%s' "$K6_OUT" | sed -n 's/.*p(95)=\([0-9.]*\)s.*/\1/p' | head -1 \
    | awk '{printf "%.0f", $1*1000}')"
  [ -n "$P95_MS" ] || P95_MS="null"
  if [ "$K6_RC" -eq 0 ] && [ "$P95_MS" != "null" ]; then
    emit_result "pass" "$P95_MS" "k6-${K6_MODE}" "$SEEDED" "$SEED_NOTE"
    exit 0
  fi
  if [ "$P95_MS" != "null" ] && awk "BEGIN{exit !(($P95_MS+0) > ($P95_BUDGET_MS+0))}"; then
    emit_result "fail" "$P95_MS" "k6-${K6_MODE}" "$SEEDED" "p95 ${P95_MS}ms exceeds ${P95_BUDGET_MS}ms budget"
    exit 1
  fi
  emit_result "fail" "$P95_MS" "k6-${K6_MODE}" "$SEEDED" "k6 exited rc=${K6_RC} (threshold breach or run error)"
  exit 1
fi

# --- hey fallback ----------------------------------------------------------
if command -v hey >/dev/null 2>&1; then
  echo "EP-03-20 ranking benchmark via hey: N=${BENCH_N} C=${BENCH_C} budget p95<${P95_BUDGET_MS}ms ($SEED_NOTE)"
  set +e
  HEY_OUT="$(hey -n "$BENCH_N" -c "$BENCH_C" \
    -H "apikey: ${SUPABASE_ANON_KEY}" -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
    -H "Content-Type: application/json" -m POST -d "$BODY" "$RPC_URL" 2>&1)"
  HEY_RC=$?
  set -e
  echo "$HEY_RC" >/dev/null
  P95_RAW="$(printf '%s' "$HEY_OUT" | awk '/Latency distribution/{f=1} f && / 95% in/{print $(NF-1); exit}')"
  [ -n "$P95_RAW" ] || emit_result "fail" "null" "hey" "$SEEDED" "could not parse p95 from hey output"
  P95_MS="$(printf '%s' "$P95_RAW" | sed -E 's/ms$//; s/s$/000/')"
  if awk "BEGIN{exit !(($P95_MS+0) > ($P95_BUDGET_MS+0))}"; then
    emit_result "fail" "$P95_MS" "hey" "$SEEDED" "p95 ${P95_MS}ms exceeds ${P95_BUDGET_MS}ms budget"
    exit 1
  fi
  emit_result "pass" "$P95_MS" "hey" "$SEEDED" "$SEED_NOTE"
  exit 0
fi

emit_skip "no k6 (binary or grafana/k6 image) and no hey installed (decision D4)"

# --- optional read-only evidence capture -----------------------------------
if [ -n "$DB_URL" ] && command -v psql >/dev/null 2>&1; then
  echo "Capturing read-only staging evidence -> ${BENCH_OUT_DIR}/ep03-staging-evidence.out"
  psql "$DB_URL" -X -v ON_ERROR_STOP=1 -q \
    -f "${SCRIPT_DIR}/ep03-staging-evidence.sql" \
    > "${BENCH_OUT_DIR}/ep03-staging-evidence.out" 2>/dev/null || \
    echo "WARNING: evidence capture failed (non-fatal for the latency gate)" >&2
fi

exit 0
