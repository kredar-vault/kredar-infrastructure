#!/usr/bin/env bash
# Deploy (or roll back) the Kredar platform for one environment. Runs ON the
# target EC2 host. The GitHub Actions deploy job rsyncs the repo files + the
# rendered runtime env here over SSH, then invokes this script.
#
# The runtime env file (env/<env>.runtime.env) already contains everything —
# non-secret config, pinned image tags, and the secrets sourced from GitHub.
# The last-known-good copy is kept as env/<env>.runtime.env.deployed and is the
# automatic rollback target.
#
# Flow:
#   1. docker login GHCR (creds read from the runtime env)
#   2. pull + up -d with the incoming env
#   3. health-check; if it fails, AUTO-ROLLBACK to the last-known-good env
#
# Usage:  scripts/deploy.sh <staging|production>
set -euo pipefail

ENV_NAME="${1:?usage: deploy.sh <staging|production>}"
REPO_DIR="${REPO_DIR:-/opt/kredar-infrastructure}"
cd "$REPO_DIR"

case "$ENV_NAME" in
  staging)    OVERRIDE=compose/docker-compose.staging.yml ;;
  production) OVERRIDE=compose/docker-compose.production.yml ;;
  *) echo "unknown environment: $ENV_NAME" >&2; exit 2 ;;
esac

BASE=compose/docker-compose.yml
INCOMING="env/${ENV_NAME}.runtime.env"
DEPLOYED="env/${ENV_NAME}.runtime.env.deployed"

[[ -f "$INCOMING" ]] || { echo "ERROR: $INCOMING not present (was it shipped?)" >&2; exit 1; }

# --- Shared-Traefik single-box mode (opt-in via EDGE_MODE=shared) -----------
# When set, this environment is co-located with other products/environments
# behind ONE shared edge Traefik. We run the stack as its own project
# (kredar-<env>), env-scope every container/network/router name via
# COMPOSE_NAME_SUFFIX, point the routing labels at the external `edge` network,
# and bring that shared edge Traefik up (idempotently). When EDGE_MODE is unset,
# none of this applies and the deploy behaves exactly as before.
SHARED_OVERLAY=()
PROJECT_ARGS=()
if grep -qE '^EDGE_MODE=shared' "$INCOMING"; then
  echo "==> EDGE_MODE=shared: co-locating ${ENV_NAME} behind the shared edge Traefik."
  export COMPOSE_NAME_SUFFIX="-${ENV_NAME}"
  export ENVIRONMENT="${ENV_NAME}"
  export TRAEFIK_DOCKER_NETWORK="edge"
  export HEALTHCHECK_NETWORK="kredar-${ENV_NAME}-internal"
  SHARED_OVERLAY=(-f compose/docker-compose.shared.yml)
  PROJECT_ARGS=(-p "kredar-${ENV_NAME}")
  docker network inspect edge >/dev/null 2>&1 || docker network create edge
  docker compose --project-directory "$REPO_DIR" -p edge \
    -f compose/docker-compose.edge.yml --env-file "$INCOMING" up -d
fi

deploy_with() {
  local ef="$1"
  # --project-directory pins relative bind-mount paths (./traefik) to the repo
  # root rather than the compose/ subdir where the files live.
  # PROJECT_ARGS/SHARED_OVERLAY are empty unless EDGE_MODE=shared.
  docker compose "${PROJECT_ARGS[@]}" --project-directory "$REPO_DIR" -f "$BASE" -f "$OVERRIDE" "${SHARED_OVERLAY[@]}" --env-file "$ef" pull
  docker compose "${PROJECT_ARGS[@]}" --project-directory "$REPO_DIR" -f "$BASE" -f "$OVERRIDE" "${SHARED_OVERLAY[@]}" --env-file "$ef" up -d --remove-orphans --force-recreate
}

ghcr_login_from() {
  local ef="$1" u t
  u="$(sed -n 's/^GHCR_USER=//p'  "$ef" | head -n1)"
  t="$(sed -n 's/^GHCR_TOKEN=//p' "$ef" | head -n1)"
  [[ -n "$t" ]] && echo "$t" | docker login ghcr.io -u "${u:-x-access-token}" --password-stdin || true
}

echo "==> Deploying ${ENV_NAME}"
ghcr_login_from "$INCOMING"
deploy_with "$INCOMING"

if scripts/healthcheck.sh; then
  echo "==> ${ENV_NAME} healthy; deploy succeeded."
  [[ -f "$DEPLOYED" ]] && cp "$DEPLOYED" "${DEPLOYED}.prev"  # keep one step of history
  cp "$INCOMING" "$DEPLOYED"          # mark this env as last-known-good
  docker image prune -f >/dev/null 2>&1 || true
else
  echo "!!! ${ENV_NAME} health checks FAILED." >&2
  if [[ -f "$DEPLOYED" ]]; then
    echo "    Auto-rolling back to the last-known-good release." >&2
    ghcr_login_from "$DEPLOYED"
    deploy_with "$DEPLOYED"
    if scripts/healthcheck.sh; then
      echo "==> Rollback restored the previous healthy version." >&2
    else
      echo "XXX Rollback ALSO failed — manual intervention required." >&2
    fi
  else
    echo "    No previous release to roll back to (first deploy)." >&2
  fi
  exit 1
fi
