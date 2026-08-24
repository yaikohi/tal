########################################
# Kubernetes auth method for OpenBao.
#
# Workloads authenticate to OpenBao by presenting their projected
# ServiceAccount token. OpenBao verifies it by calling TokenReview on the
# cluster, authenticated as the dedicated `vault-auth` SA (see
# yaya-ops/manifests/openbao-k8s-auth.yaml).
########################################

# Read the long-lived token Secret for the vault-auth ServiceAccount.
data "kubernetes_secret_v1" "vault_auth_token" {
  metadata {
    name      = "vault-auth-token"
    namespace = "openbao"
  }
}

# Cluster CA cert, served by the API server itself.
data "kubernetes_config_map_v1" "kube_root_ca" {
  metadata {
    name      = "kube-root-ca.crt"
    namespace = "openbao"
  }
}

resource "vault_auth_backend" "kubernetes" {
  type        = "kubernetes"
  path        = "kubernetes"
  description = "Kubernetes auth for in-cluster workloads"
}

resource "vault_kubernetes_auth_backend_config" "this" {
  backend            = vault_auth_backend.kubernetes.path
  kubernetes_host    = "https://kubernetes.default.svc"
  kubernetes_ca_cert = data.kubernetes_config_map_v1.kube_root_ca.data["ca.crt"]
  token_reviewer_jwt = data.kubernetes_secret_v1.vault_auth_token.data["token"]

  # Talos uses projected SA tokens whose `iss` claim does not match the
  # default expected value. Skipping iss validation is the standard
  # workaround; TokenReview still verifies the signature and audience.
  disable_iss_validation = true
}

########################################
# Per-app policies + roles.
#
# Each app gets read access to its own subtree under the `apps` KVv2 mount,
# bound to a (namespace, ServiceAccount) tuple in the cluster.
########################################

locals {
  # service_account is the SA that exists in `namespace` and is referenced
  # by the per-namespace ESO SecretStore.
  vault_apps = {
    homepage = {
      namespace       = "homepage"
      service_account = "vault-auth"
      kv_subpath      = "homepage"
    }
    media = {
      namespace       = "media"
      service_account = "vault-auth"
      kv_subpath      = "media"
    }
    immich = {
      namespace       = "immich"
      service_account = "vault-auth"
      kv_subpath      = "immich"
    }
    nats = {
      namespace       = "nats"
      service_account = "vault-auth"
      kv_subpath      = "nats"
    }
    observability = {
      namespace       = "observability"
      service_account = "vault-auth"
      kv_subpath      = "observability"
    }
    valheim = {
      namespace       = "valheim"
      service_account = "vault-auth"
      kv_subpath      = "valheim"
    }
    zot = {
      namespace       = "zot"
      service_account = "vault-auth"
      kv_subpath      = "zot"
    }
  }
}

resource "vault_policy" "app" {
  for_each = local.vault_apps
  name     = each.key
  policy   = <<-EOT
    path "${vault_mount.kvv2.path}/data/${each.value.kv_subpath}/*" {
      capabilities = ["read"]
    }
    path "${vault_mount.kvv2.path}/data/${each.value.kv_subpath}" {
      capabilities = ["read"]
    }
    path "${vault_mount.kvv2.path}/metadata/${each.value.kv_subpath}/*" {
      capabilities = ["read", "list"]
    }
    path "${vault_mount.kvv2.path}/metadata/${each.value.kv_subpath}" {
      capabilities = ["read", "list"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "app" {
  for_each                         = local.vault_apps
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = each.key
  bound_service_account_names      = [each.value.service_account]
  bound_service_account_namespaces = [each.value.namespace]
  token_policies                   = [vault_policy.app[each.key].name]
  token_ttl                        = 3600
  token_max_ttl                    = 86400

  depends_on = [vault_kubernetes_auth_backend_config.this]
}
