#!/usr/bin/env bash
# Manual rollback: redeploy the last-known-good runtime env captured by deploy.sh
# (env/<env>.runtime.env.deployed.prev -> .deployed). Runs ON the host.
#
# Normal rollback is: revert versions/<env>.env in git and re-run the deploy.
# This script is the host-side break-glass when you can't wait for CI.
#
# Usage:  scripts/rollback.sh <staging|production>
set -euo pipefail

ENV_NAME="${1:?usage: rollback.sh <staging|production>}"
REPO_DIR="${REPO_DIR:-/opt/kredar-infrastructure}"
cd "$REPO_DIR"

DEPLOYED="env/${ENV_NAME}.runtime.env.deployed"
PREV="${DEPLOYED}.prev"

[[ -f "$PREV" ]] || { echo "ERROR: no previous release ($PREV) to roll back to" >&2; exit 1; }

echo "==> Rolling ${ENV_NAME} back to the previous release."
cp "$PREV" "env/${ENV_NAME}.runtime.env"
REPO_DIR="$REPO_DIR" scripts/deploy.sh "$ENV_NAME"
