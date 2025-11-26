resource "helm_release" "cilium" {
  name       = "cilium"
  namespace  = "kube-system"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = "1.16.1"
  wait       = true
  timeout    = 600

  values = [
    yamlencode({
      ipam                 = { mode = "kubernetes" }
      k8sServiceHost       = "localhost"
      k8sServicePort       = 7445
      kubeProxyReplacement = true
      securityContext = {
        capabilities = {
          ciliumAgent      = ["CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
          cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
        }
      }
      cgroup = {
        autoMount = { enabled = false }
        hostRoot  = "/sys/fs/cgroup"
      }
      l2announcements = { enabled = true }
      hubble = {
        relay = { enabled = true }
        ui    = { enabled = true }
      }
    })
  ]
}

resource "terraform_data" "cilium_config" {
  triggers_replace = [var.lb_cidr]
  depends_on       = [helm_release.cilium]

  provisioner "local-exec" {
    command = <<EOT
cat <<EOF | kubectl --kubeconfig ${var.kubeconfig_path} apply -f -
---
apiVersion: cilium.io/v2alpha1
kind: CiliumL2AnnouncementPolicy
metadata:
  name: external
spec:
  loadBalancerIPs: true
  interfaces:
  - ens18
  nodeSelector:
    matchExpressions:
    - key: node-role.kubernetes.io/control-plane
      operator: DoesNotExist
---
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: external
spec:
  blocks:
  - cidr: ${var.lb_cidr}
EOF
EOT
  }
}
