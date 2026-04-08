#!/usr/bin/env bash
#
# smoke.sh — standalone smoke test for the governor chart.
#
# Spins up a throwaway kind cluster, deploys postgres, installs the chart from
# this working tree, logs in to governor-api, and verifies a worker registers
# as an ALIVE agent via GET /api/v1/agents. Tears everything down on exit.
#
# Usage:
#   ./scripts/smoke.sh                  # full run, clean up
#   KEEP_CLUSTER=1 ./scripts/smoke.sh   # leave kind cluster up for manual poking
#
# Requirements: kind, kubectl, helm, jq, curl.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART="$REPO_ROOT/charts/governor"
CLUSTER="governor-smoke"
NS="governor"
RELEASE="governor"
ADMIN_EMAIL="test@synthesized.io"
ADMIN_PASS="Qq12345_"
# 512-bit base64 JWT secret (required by governor-api).
JWT_SECRET="M0lryns8NaK/ZCBeMC/g2EPzMmKieJbFBrYtKbQuG4sWCCMWFMRS8F7ZN1/xxnaMkdrnWQPmzmymNuIRQbmWNw=="
PORT_FWD_PID=""

log()  { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m!!  %s\033[0m\n" "$*"; }
die()  { printf "\033[1;31mXX  %s\033[0m\n" "$*" >&2; exit 1; }

cleanup() {
  local ec=$?
  set +e
  [[ -n "$PORT_FWD_PID" ]] && kill "$PORT_FWD_PID" 2>/dev/null
  if [[ -z "${KEEP_CLUSTER:-}" ]]; then
    log "Deleting kind cluster $CLUSTER"
    kind delete cluster --name "$CLUSTER" >/dev/null 2>&1
  else
    warn "KEEP_CLUSTER=1 — leaving cluster. Delete with: kind delete cluster --name $CLUSTER"
  fi
  exit "$ec"
}
trap cleanup EXIT INT TERM

for t in kind kubectl helm jq curl; do
  command -v "$t" >/dev/null || die "missing required tool: $t"
done

###############################################################################
log "1/6  Creating kind cluster: $CLUSTER"
if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER" --wait 120s
fi
kubectl cluster-info --context "kind-$CLUSTER" >/dev/null

###############################################################################
log "2/6  Creating namespace + postgres"
kubectl create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: { name: postgres }
spec:
  replicas: 1
  selector: { matchLabels: { app: postgres } }
  template:
    metadata: { labels: { app: postgres } }
    spec:
      containers:
        - name: postgres
          image: postgres:18-alpine
          env:
            - { name: POSTGRES_USER,     value: "governor" }
            - { name: POSTGRES_PASSWORD, value: "governor" }
            - { name: POSTGRES_DB,       value: "governor" }
          ports: [{ containerPort: 5432 }]
          readinessProbe:
            exec: { command: ["pg_isready", "-U", "governor"] }
            initialDelaySeconds: 5
            periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata: { name: postgres }
spec:
  selector: { app: postgres }
  ports: [{ port: 5432, targetPort: 5432 }]
EOF
kubectl -n "$NS" rollout status deploy/postgres --timeout=180s

###############################################################################
log "3/6  helm install $RELEASE from $CHART"
VALUES=$(mktemp)
trap 'rm -f "$VALUES"' RETURN
cat > "$VALUES" <<EOF
api:
  image: { tag: latest }
  container:
    config:
      SPRING_PROFILES_ACTIVE: production
      VERSION: smoke
      S3_ENABLED: "false"
    secretConfig:
      SPRING_DATASOURCE_URL: "jdbc:postgresql://postgres:5432/governor"
      SPRING_DATASOURCE_USERNAME: "governor"
      SPRING_DATASOURCE_PASSWORD: "governor"
      JWT_SECRET: "$JWT_SECRET"
      ADMIN_EMAIL: "$ADMIN_EMAIL"
      ADMIN_DEFAULT_PASSWORD: "$ADMIN_PASS"

front:
  image: { tag: latest }

worker:
  image:
    tag: latest
    pullPolicy: IfNotPresent
  persistence:
    enabled: false
EOF

helm install "$RELEASE" "$CHART" -n "$NS" -f "$VALUES" --wait --timeout 10m || {
  warn "helm install failed — pod status:"
  kubectl -n "$NS" get pods
  warn "api logs:"
  kubectl -n "$NS" logs deploy/governor-api --tail=40 2>/dev/null || true
  exit 1
}

###############################################################################
log "4/6  Waiting for rollouts"
kubectl -n "$NS" rollout status deploy/governor-api    --timeout=300s
# Worker deployment is `governor-worker` by default on the new chart.
# Fall back to `governor-agent` if an override is set elsewhere.
WORKER_DEPLOY=$(kubectl -n "$NS" get deploy -o name | grep -E "governor-(worker|agent)$" | head -1)
[[ -n "$WORKER_DEPLOY" ]] || die "no worker/agent deployment found"
kubectl -n "$NS" rollout status "$WORKER_DEPLOY" --timeout=300s

###############################################################################
log "5/6  Port-forward + login"
kubectl -n "$NS" port-forward svc/governor-api 8081:80 >/tmp/pf.log 2>&1 &
PORT_FWD_PID=$!
for _ in $(seq 1 30); do
  curl -sf http://localhost:8081/ >/dev/null 2>&1 && break
  sleep 2
done

TOKEN=$(curl -sf -X POST http://localhost:8081/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}" \
  | jq -r '.access_token')
[[ -n "$TOKEN" && "$TOKEN" != "null" ]] || die "login failed — see /tmp/pf.log"

###############################################################################
log "6/6  Polling /api/v1/agents for an ALIVE worker"
for i in $(seq 1 30); do
  RESP=$(curl -sf http://localhost:8081/api/v1/agents -H "Authorization: Bearer $TOKEN" || echo "[]")
  COUNT=$(echo "$RESP" | jq 'if type=="array" then [.[] | select(.status=="ALIVE")] | length else 0 end')
  if [[ "${COUNT:-0}" -ge 1 ]]; then
    echo "$RESP" | jq .
    log "✓ Smoke PASS: $COUNT ALIVE agent(s) registered"
    exit 0
  fi
  printf "   (%d/30) no ALIVE agent yet...\r" "$i"
  sleep 3
done

echo
warn "no ALIVE agent after 90s. last /api/v1/agents response:"
echo "$RESP" | jq . || echo "$RESP"
warn "worker logs:"
kubectl -n "$NS" logs "$WORKER_DEPLOY" --tail=60 || true
die "Smoke FAIL: worker did not register"
