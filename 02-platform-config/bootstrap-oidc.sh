#!/usr/bin/env bash
# Idempotent OIDC bootstrap for OpenBao.
#
# Why a script instead of Terraform: the hashicorp/vault provider's
# `vault_jwt_auth_backend` resource is incompatible with OpenBao's
# `oidc`-typed mount (both import and PUT on /v1/auth/oidc/config fail),
# and there is no first-party openbao/openbao Terraform provider as of
# writing. See the comment in openbao_oidc.tf for details.
#
# Safe to re-run: enables the mount only if missing, and `bao write`
# upserts config/role. Run after every OpenBao re-init/wipe.
#
# Usage:
#   cd tal/02-platform-config
#   ./bootstrap-oidc.sh            # reads creds from secret.tfvars
#
# Requires:
#   - KUBECONFIG pointing at the yaya cluster
#   - openbao-0 Running and unsealed
#   - secret.tfvars present alongside this script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TFVARS="${SCRIPT_DIR}/secret.tfvars"

if [[ ! -f "$TFVARS" ]]; then
  echo "ERROR: $TFVARS not found" >&2
  exit 1
fi

# Pull values out of secret.tfvars (HCL-ish: key = "value").
extract() {
  grep -E "^${1}[[:space:]]*=" "$TFVARS" | head -1 | cut -d'"' -f2
}

ROOT_TOKEN="$(extract vault_root_token)"
ZID="$(extract zitadel_client_id)"
ZSEC="$(extract zitadel_client_secret)"

if [[ -z "$ROOT_TOKEN" || -z "$ZID" || -z "$ZSEC" ]]; then
  echo "ERROR: missing vault_root_token / zitadel_client_id / zitadel_client_secret in $TFVARS" >&2
  exit 1
fi

# Tuneables — keep in sync with allowed redirect URIs configured in Zitadel.
OIDC_DISCOVERY_URL="${OIDC_DISCOVERY_URL:-https://zitadel.o0o.zip}"
BAO_UI_HOST="${BAO_UI_HOST:-bao.ykhi.xyz}"
REDIRECT_URIS="https://${BAO_UI_HOST}/ui/vault/auth/oidc/oidc/callback,http://localhost:8250/oidc/callback"
POLICY="${POLICY:-super-admin}"
ROLE="${ROLE:-admin}"

POD="${POD:-openbao-0}"
NS="${NS:-openbao}"

echo "==> Ensuring oidc auth method is enabled on ${POD}"
kubectl -n "$NS" exec -i "$POD" -- env BAO_TOKEN="$ROOT_TOKEN" sh -c '
  set -e
  if bao auth list 2>/dev/null | awk "{print \$1}" | grep -qx "oidc/"; then
    echo "  oidc/ already mounted"
  else
    bao auth enable oidc
  fi
'

echo "==> Marking oidc/ as visible to unauthenticated UI users"
# Without this, the UI login dropdown only shows "Token" and OIDC can't be
# selected — leading to misleading "permission denied" errors.
kubectl -n "$NS" exec -i "$POD" -- env BAO_TOKEN="$ROOT_TOKEN" \
  bao auth tune -listing-visibility=unauth oidc/

echo "==> Writing oidc config"
kubectl -n "$NS" exec -i "$POD" -- env \
  BAO_TOKEN="$ROOT_TOKEN" \
  OIDC_DISCOVERY_URL="$OIDC_DISCOVERY_URL" \
  ZID="$ZID" ZSEC="$ZSEC" \
  ROLE="$ROLE" \
  sh -c '
    set -e
    bao write auth/oidc/config \
      oidc_discovery_url="$OIDC_DISCOVERY_URL" \
      oidc_client_id="$ZID" \
      oidc_client_secret="$ZSEC" \
      default_role="$ROLE"
  '

echo "==> Writing oidc role/${ROLE} -> policy=${POLICY}"
kubectl -n "$NS" exec -i "$POD" -- env \
  BAO_TOKEN="$ROOT_TOKEN" \
  ROLE="$ROLE" \
  REDIRECT_URIS="$REDIRECT_URIS" \
  POLICY="$POLICY" \
  sh -c '
    set -e
    bao write "auth/oidc/role/$ROLE" \
      role_type="oidc" \
      user_claim="sub" \
      allowed_redirect_uris="$REDIRECT_URIS" \
      oidc_scopes="openid,profile,email" \
      token_policies="$POLICY"
  '

echo "==> Verifying"
kubectl -n "$NS" exec "$POD" -- env BAO_TOKEN="$ROOT_TOKEN" \
  bao read "auth/oidc/role/$ROLE"

echo
echo "OK — open https://${BAO_UI_HOST} and choose 'OIDC' (role: ${ROLE})."
