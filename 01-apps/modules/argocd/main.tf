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
          type           = "LoadBalancer"
          loadBalancerIP = "192.168.20.222"
          annotations = {
            # This tells Cilium to announce this specific IP via L2
            "io.cilium/lb-ipam-ips" = "192.168.20.222"
          }
        }
        # Disable TLS on the pod level so we don't deal with certs inside the pod for now
        extraArgs = ["--insecure"]
      }

      # Deploy the root app-of-apps Application as part of this chart.
      # This avoids a separate argocd-apps helm release whose Application
      # resource can become orphaned during destroy/apply cycles (ArgoCD's
      # selfHeal recreates it without Helm ownership labels).
      extraObjects = [
        {
          apiVersion = "argoproj.io/v1alpha1"
          kind       = "Application"
          metadata = {
            name      = "root"
            namespace = "argocd"
          }
          spec = {
            project = "default"
            source = {
              repoURL        = "https://codeberg.org/ykhi/yaya-ops.git"
              targetRevision  = "main"
              path           = "apps"
            }
            destination = {
              server    = "https://kubernetes.default.svc"
              namespace = "argocd"
            }
            syncPolicy = {
              automated = {
                prune    = false
                selfHeal = true
              }
              syncOptions = ["CreateNamespace=true"]
            }
          }
        }
      ]
    })
  ]
}
