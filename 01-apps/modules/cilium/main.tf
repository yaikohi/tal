resource "helm_release" "cilium" {
  name       = "cilium"
  namespace  = "kube-system"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = "1.19.0"
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

resource "kubernetes_manifest" "cilium_l2_announcement_policy" {
  manifest = {
    apiVersion = "cilium.io/v2alpha1"
    kind       = "CiliumL2AnnouncementPolicy"
    metadata = {
      name = "external"
    }
    spec = {
      loadBalancerIPs = true
      # ens18 = Proxmox VM nodes' NIC; eno1 = bare-metal game-01's NIC. Both must be
      # listed or L2 announcement (ARP) fails on nodes whose NIC isn't matched — e.g.
      # the valheim LB IP wasn't reachable because its pod is pinned to game-01 (eno1).
      interfaces      = ["ens18", "eno1"]
      nodeSelector = {
        matchExpressions = [
          {
            key      = "node-role.kubernetes.io/control-plane"
            operator = "DoesNotExist"
          }
        ]
      }
    }
  }

  depends_on = [helm_release.cilium]
}

resource "kubernetes_manifest" "cilium_loadbalancer_ip_pool" {
  manifest = {
    apiVersion = "cilium.io/v2alpha1"
    kind       = "CiliumLoadBalancerIPPool"
    metadata = {
      name = "external"
    }
    spec = {
      blocks = [
        {
          start = "192.168.20.220"
          stop  = "192.168.20.250"
        }
      ]
    }
  }

  depends_on = [helm_release.cilium]
}
