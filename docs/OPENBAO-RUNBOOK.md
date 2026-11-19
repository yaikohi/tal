# OpenBao operations runbook

OpenBao runs as a 3-replica Raft HA cluster in the `openbao` namespace,
backed by NFS PVCs. Auto-unseal is not configured (yet), so each replica
must be manually unsealed after any restart.

This document covers day-0 init, the unseal procedure, and the workflow
for adding a new application that consumes secrets via External Secrets
Operator (ESO).

> **After a full re-init / data wipe**, four manual steps are required
> before the cluster is usable again — none of them happen automatically
> from `tofu apply`:
>
> 1. `bao operator init` on `openbao-0` (section 1)
> 2. Unseal `openbao-{0,1,2}` (section 2). Non-leader pods auto-join
>    raft via `retry_join` in `charts/openbao/values.yaml`.
> 3. `tofu apply` in `tal/02-platform-config` — re-seeds KVv2 mount,
>    Kubernetes auth method, per-app policies/roles, KV secrets.
>    During bootstrap when `bao.ykhi.xyz` round-robins into a sealed
>    standby, override the provider address:
>    ```sh
>    kubectl -n openbao port-forward openbao-0 18200:8200 &
>    tofu apply -var-file=secret.tfvars \
>      -var "vault_addr_override=http://127.0.0.1:18200"
>    ```
> 4. `./bootstrap-oidc.sh` (section 3a) — restores the Zitadel OIDC
>    auth method, which is not managed by Terraform.

---

## 1. Day-0: initialize the cluster

Run once, on the very first pod (`openbao-0`):

```sh
export KUBECONFIG=tal/00-infra/kubeconfig

# Wait until openbao-0 is Running and listening on :8200.
kubectl -n openbao exec -ti openbao-0 -- bao operator init \
  -key-shares=5 -key-threshold=3
```

Save the **5 unseal keys** and the **initial root token** in a password
manager. Anyone with 3 unseal keys can decrypt the data; the root token
is required for the first bootstrap of policies / auth methods.

> The root token in `tal/02-platform-config/secret.tfvars` must match
> the initial root token (or a token minted from it with sufficient
> privileges). Rotate later via `bao token create -policy=super-admin`
> + revoke the original root.

---

## 2. Unsealing (every restart)

Each pod stores its own encrypted Raft data and starts sealed. After a
node reboot, pod reschedule, or `kubectl rollout restart`:

```sh
for pod in openbao-0 openbao-1 openbao-2; do
  for i in 1 2 3; do
    kubectl -n openbao exec -ti $pod -- bao operator unseal
    # paste one of the unseal keys at the prompt
  done
done
```

Verify:

```sh
kubectl -n openbao exec openbao-0 -- bao status   # Sealed=false, HA Mode=active
kubectl -n openbao exec openbao-1 -- bao status   # Sealed=false, HA Mode=standby
kubectl -n openbao exec openbao-2 -- bao status   # Sealed=false, HA Mode=standby
```

While any replica is sealed:
- ESO `ExternalSecret` resources report `SecretSyncError` and retry on
  their refresh interval.
- Newly-scheduled pods that need a synced Secret stay `ContainerCreating`.

Both recover automatically once OpenBao is unsealed.

---

## 3. Bootstrap order

The platform is layered. From a cold start:

1. **`tal/00-infra`** — Talos cluster + kubeconfig.
2. **`tal/01-apps`** — Cilium, ArgoCD, NFS provisioner.
3. **GitOps wave** (ArgoCD picks up `yaya-ops/apps/`):
   - cert-manager (`sync-wave: -3`)
   - cert-manager-manifests (`sync-wave: -1`)
   - **external-secrets** (`sync-wave: -2`)
   - openbao (default wave)
4. **Manual**: init + unseal OpenBao (section 1 + 2).
5. **Manual**: bootstrap the OIDC auth method (section 3a) — Terraform
   cannot manage it (see note in `tal/02-platform-config/openbao_oidc.tf`).
6. **`tal/02-platform-config`** — `tofu apply` provisions KVv2, the
   `super-admin` policy, the Kubernetes auth method, per-app
   policies/roles, and seeds the per-app KV secrets.
7. ESO reconciles `ExternalSecret`s; per-app Secrets materialize; app
   pods that were blocked on those Secrets become Ready.

---

## 3a. Bootstrap OIDC manually

The `hashicorp/vault` Terraform provider's `vault_jwt_auth_backend`
resource is incompatible with OpenBao's `oidc`-typed mount (both import
and the `/v1/auth/oidc/config` PUT fail), and there is no first-party
`openbao/openbao` provider. So OIDC is created out-of-band, once, with
the `bao` CLI. The `super-admin` policy it binds to is still
TF-managed in `openbao_oidc.tf`.

```sh
cd ~/projects/tal/02-platform-config
export KUBECONFIG=~/projects/tal/00-infra/kubeconfig
export ROOT=$(grep '^vault_root_token'      secret.tfvars | cut -d'"' -f2)
export ZID=$( grep '^zitadel_client_id'     secret.tfvars | cut -d'"' -f2)
export ZSEC=$(grep '^zitadel_client_secret' secret.tfvars | cut -d'"' -f2)

kubectl -n openbao exec -i openbao-0 -- env \
  BAO_TOKEN="$ROOT" ZID="$ZID" ZSEC="$ZSEC" \
  sh -c '
    set -e
    bao auth enable oidc
    bao write auth/oidc/config \
      oidc_discovery_url="https://zitadel.o0o.zip" \
      oidc_client_id="$ZID" \
      oidc_client_secret="$ZSEC" \
      default_role="admin"
    bao write auth/oidc/role/admin \
      role_type="oidc" \
      user_claim="sub" \
      allowed_redirect_uris="https://bao.ykhi.xyz/ui/vault/auth/oidc/oidc/callback,http://localhost:8250/oidc/callback" \
      oidc_scopes="openid,profile,email" \
      token_policies="super-admin"
  '

# Verify
kubectl -n openbao exec openbao-0 -- env BAO_TOKEN="$ROOT" \
  bao read auth/oidc/role/admin
```

Test: open `https://bao.ykhi.xyz` → "Sign in with OIDC" (role `admin`)
→ Zitadel → back to the UI authenticated against the `super-admin`
policy.

To rotate the Zitadel client secret later: update `zitadel_client_secret`
in `secret.tfvars`, then re-run the `bao write auth/oidc/config …`
command above (the rest of the bootstrap is idempotent and can be
skipped).

---

## 4. Adding a new application that needs secrets

1. **Define the role in Terraform** —
   `tal/02-platform-config/kubernetes-auth.tf`, append to `local.vault_apps`:
   ```hcl
   myapp = {
     namespace       = "myapp"
     service_account = "vault-auth"
     kv_subpath      = "myapp"
   }
   ```
2. **Seed the secret** — `tal/02-platform-config/apps-secrets.tf`:
   ```hcl
   resource "vault_kv_secret_v2" "myapp" {
     mount     = vault_mount.kvv2.path
     name      = "myapp"
     data_json = jsonencode({ API_KEY = var.myapp_api_key })
   }
   ```
   then `tofu apply -var-file=secret.tfvars`.
3. **Wire it from GitOps** — add a manifest under `yaya-ops/manifests/`
   matching the app's existing `include:` glob, defining:
   - `ServiceAccount/vault-auth` in the app namespace,
   - `SecretStore/openbao` with `role: myapp`,
   - `ExternalSecret` materializing the target Secret.

   See [yaya-ops/manifests/homepage-externalsecret.yaml](../../yaya-ops/manifests/homepage-externalsecret.yaml)
   for a copy-paste template.
4. **Consume the Secret** in the app chart values (`envFrom`,
   `valueFrom.secretKeyRef`, `existingSecret`, etc.).

---

## 5. Out of scope (future work)

- Auto-unseal via Transit secret engine on a second OpenBao instance, or
  cloud KMS — would remove the manual unseal step.
- External (non-cluster) access — would add an AppRole or JWT auth
  method alongside Kubernetes auth.
- Audit log shipping off the `audit` PVC.
- Backup/restore strategy for the Raft snapshot
  (`bao operator raft snapshot save`).
