locals {
  talconfig = yamldecode(file("${path.module}/talconfig.yaml"))

  cluster_name = local.talconfig.clusterName

  talos_config = yamldecode(file("${path.module}/clusterconfig/talosconfig"))

  client_config = {
    ca_certificate     = local.talos_config.contexts[local.cluster_name].ca
    client_certificate = local.talos_config.contexts[local.cluster_name].crt
    client_key         = local.talos_config.contexts[local.cluster_name].key
  }


  nodes = {
    for node in local.talconfig.nodes : node.hostname => {
      ip = node.ipAddress
      # specific PVE node logic (see explanation below)
      target_node = try(node.machineSpec.target_node, "dusk")
      type        = node.controlPlane ? "controlplane" : "worker"
      vm_id       = try(node.machineSpec.vmid, null)
      mac         = try(node.machineSpec.mac, null)
    }
  }
}

################################################################################
# 1. PROXMOX VM CREATION (bpg/proxmox)
################################################################################

resource "proxmox_virtual_environment_vm" "talos_node" {
  for_each      = local.nodes
  name          = "${local.cluster_name}--${each.key}"
  node_name     = each.value.target_node
  vm_id         = each.value.vm_id
  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  on_boot       = true

  # Basic VM Specs
  # boot_order = ["ide0", "scsi0"]
  boot_order = ["scsi0", "ide0"]
  started    = true
  agent {
    enabled = true
    trim    = true
  }

  operating_system {
    type = "l26"
  }

  cpu {
    type  = "host"
    cores = 4
  }

  memory {
    dedicated = 4 * 1024
  }

  network_device {
    vlan_id     = 20
    bridge      = "vmbr0"
    mac_address = each.value.mac
  }

  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "4m"
  }

  # --- ISO CONFIGURATION (Boot Drive) ---
  disk {
    file_id   = "local:iso/talos-v1.11.5.iso"
    interface = "ide0"
  }
  # --- INSTALLATION DRIVE (Empty Disk) ---
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 20
    file_format  = "raw"
    iothread     = true
  }
  # IP Configuration via Cloud-Init (Required for Terraform to reach the node)
  # Even though Talos is "immutable", it needs an IP to accept the config bundle.
  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = "192.168.20.1" # <--- TODO: Update your Gateway
      }
    }
  }
}

################################################################################
# 2. TALOS CONFIGURATION APPLY
################################################################################

resource "talos_machine_configuration_apply" "node_config" {
  for_each                    = local.nodes
  client_configuration        = local.client_config
  machine_configuration_input = file("${path.module}/clusterconfig/${local.cluster_name}-${each.key}.yaml")
  node                        = each.value.ip
  endpoint                    = each.value.ip
  depends_on                  = [proxmox_virtual_environment_vm.talos_node]
}
################################################################################
# 3. TALOS BOOTSTRAP (Control Plane Only)
################################################################################

resource "talos_machine_bootstrap" "bootstrap" {
  node                 = local.nodes["c-01"].ip
  client_configuration = local.client_config
  endpoint             = local.nodes["c-01"].ip
  depends_on           = [talos_machine_configuration_apply.node_config]
}
################################################################################
# 4. KUBECONFIG RETRIEVAL
################################################################################

resource "talos_cluster_kubeconfig" "kubeconfig" {
  client_configuration = local.client_config
  node                 = local.nodes["c-01"].ip
  depends_on           = [talos_machine_bootstrap.bootstrap]
}

resource "local_file" "kubeconfig" {
  content  = resource.talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  filename = "${path.module}/kubeconfig"
}
