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
