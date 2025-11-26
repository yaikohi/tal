locals {
  # SETTINGS
  # This is the range of IPs that Cilium will hand out to Services of type=LoadBalancer.
  # It must be within your VLAN 20 (192.168.20.0/24) but OUTSIDE your DHCP range.
  # Example: 192.168.20.220 - 192.168.20.230
  cilium_lb_cidr = "192.168.20.220/28"
}

# ------------------------------------------------------------------------------
# 0. Wait for the api-server to be ready
# ------------------------------------------------------------------------------
resource "time_sleep" "wait_for_kubernetes" {
  create_duration = "2m"

  depends_on = [
    local_file.kubeconfig,
    talos_machine_bootstrap.bootstrap
  ]
}

# ------------------------------------------------------------------------------
# 1. Install Cilium Helm Chart
# ------------------------------------------------------------------------------
resource "helm_release" "cilium" {
  name       = "cilium"
  namespace  = "kube-system"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = "1.18.0" # Stable version
  wait       = true     # set wait=true to ensure Cilium is healthy before trying to apply policies
  timeout    = 600
  depends_on = [ # Prevents race condition
    time_sleep.wait_for_kubernetes
  ]

  values = [
    yamlencode({
      ipam = {
        mode = "kubernetes"
      }

      # Talos Specific: KubePrism
      # This allows Cilium to talk to the API server via localhost
      k8sServiceHost = "localhost"
      k8sServicePort = 7445

      # GatewayAPI support
      gatewayAPI = {
        enabled           = true
        enableAlpn        = true
        enableAppProtocol = true
      }

      # Security Context (Required for Talos)
      securityContext = {
        capabilities = {
          ciliumAgent = [
            "CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK",
            "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"
          ]
          cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
        }
      }

      # Cgroup Management (Talos handles this, so we disable auto-mount)
      cgroup = {
        autoMount = {
          enabled = false
        }
        hostRoot = "/sys/fs/cgroup"
      }

      # KubeProxy Replacement (Strict is best for performance)
      kubeProxyReplacement = true

      # L2 Announcements (Replaces MetalLB)
      l2announcements = {
        enabled = true
      }

      # Enable Hubble for Observability (Optional but recommended)
      hubble = {
        relay = { enabled = true }
        ui    = { enabled = true }
      }
    })
  ]
}

# ------------------------------------------------------------------------------
# 2. Apply L2 Announcement Policy & IP Pool
# ------------------------------------------------------------------------------
# This applies the CRDs that tell Cilium which IPs to use and which interface to announce on.
resource "terraform_data" "cilium_config" {
  triggers_replace = [local.cilium_lb_cidr]
  depends_on       = [helm_release.cilium]

  provisioner "local-exec" {
    command = <<EOT
cat <<EOF | kubectl --kubeconfig ${path.module}/kubeconfig apply -f -
---
apiVersion: cilium.io/v2alpha1
kind: CiliumL2AnnouncementPolicy
metadata:
  name: external
spec:
  loadBalancerIPs: true
  interfaces:
  - ens18 # The interface inside the Talos VM
  nodeSelector:
    matchExpressions:
    - key: node-role.kubernetes.io/control-plane
      operator: DoesNotExist # Use workers only (Remove this block to use all nodes)
---
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: external
spec:
  blocks:
  - cidr: ${local.cilium_lb_cidr}
EOF
EOT
  }
}
