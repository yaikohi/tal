resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "9.1.4"

  values = [
    yamlencode({
      server = {
        service = {
          # This uses the Cilium L2 Announcement capabilities
          type = "LoadBalancer"
        }
        # Disable TLS on the pod level so we don't deal with certs inside the pod for now
        extraArgs = ["--insecure"]
      }
    })
  ]
}

resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.2"

  values = [
    yamlencode({
      applications = {
        root = {
          namespace = "argocd"
          project   = "default"
          source = {
            repoURL        = "https://codeberg.org/ykhi/yaya-ops.git"
            targetRevision = "main"
            path           = "apps"
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "argocd"
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
            syncOptions = ["CreateNamespace=true"]
          }
        }
      }
    })
  ]

  # This is crucial: It ensures ArgoCD is fully ready before deploying apps
  depends_on = [helm_release.argocd]
}
