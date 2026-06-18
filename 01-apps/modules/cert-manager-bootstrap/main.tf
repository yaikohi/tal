# Pre-create the cert-manager namespace + Cloudflare API token Secret so that
# when ArgoCD reconciles the `cert-manager-manifests` app (which contains the
# ClusterIssuer referencing this Secret), the DNS01 solver can authenticate to
# Cloudflare immediately. Without this, the wildcard Certificate fails to issue,
# the Traefik `websecure` listener has no TLS, and `bao.ykhi.xyz` is unreachable
# — which in turn blocks `02-platform-config` from configuring OpenBao.
#
# The Secret is owned by Terraform, NOT by OpenBao/ExternalSecrets, on purpose:
# cert-manager must be independent of OpenBao to break the circular dependency.

resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = var.namespace
  }

  lifecycle {
    # ArgoCD's cert-manager Helm app may add labels/annotations to this ns.
    # Don't fight it.
    ignore_changes = [metadata[0].labels, metadata[0].annotations]
  }
}

resource "kubernetes_secret_v1" "cloudflare_api_token" {
  metadata {
    name      = var.secret_name
    namespace = kubernetes_namespace_v1.cert_manager.metadata[0].name

    # Tell ArgoCD not to prune this Secret if the app definition ever loses
    # reference to it. Terraform is the source of truth.
    annotations = {
      "argocd.argoproj.io/sync-options" = "Prune=false"
    }
  }

  type = "Opaque"

  data = {
    "api-token" = var.cloudflare_api_token
  }
}
