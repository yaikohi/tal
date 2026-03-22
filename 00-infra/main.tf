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
      ip          = node.ipAddress
      target_node = var.PROXMOX_VE_NODENAME
      type        = node.controlPlane ? "controlplane" : "worker"
      vm_id       = try(node.machineSpec.vmid, null)
      mac         = try(node.machineSpec.mac, null)
    }
  }
}

################################################################################
# 1. DOWNLOAD TALOS ISO FROM URL
################################################################################

resource "proxmox_virtual_environment_download_file" "talos_iso" {
  content_type   = "iso"
  datastore_id   = "local"
  node_name      = var.PROXMOX_VE_NODENAME
  url            = "https://factory.talos.dev/image/37a92427f8a50e9bd0b9c42547c9311bdbe4ade8c2dd8716a593b0fa09abf3e7/v1.12.3/metal-amd64.iso"
  file_name      = "talos-v1.12.3.iso"
  overwrite      = false
  verify         = false
  upload_timeout = 1800
}

################################################################################
# 2. PROXMOX VM CREATION (bpg/proxmox)
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
  boot_order    = ["scsi0", "ide0"]
  started       = true
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
    dedicated = each.value.type == "worker" ? 8 * 1024 : 4 * 1024
  }

  network_device {
    vlan_id     = 20
    bridge      = "vmbr0"
    mac_address = each.value.mac
  }

  efi_disk {
    datastore_id = "fastdata"
    file_format  = "raw"
    type         = "4m"
  }

  # --- ISO CONFIGURATION (Boot Drive) ---
  disk {
    file_id   = proxmox_virtual_environment_download_file.talos_iso.id
    interface = "ide0"
  }
  # --- INSTALLATION DRIVE (Empty Disk) ---
  disk {
    datastore_id = "fastdata"
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
        gateway = "192.168.20.1"
      }
    }
  }
}

################################################################################
# 3. TALOS CONFIGURATION APPLY
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
# 4. TALOS BOOTSTRAP (Control Plane Only)
################################################################################
resource "talos_machine_bootstrap" "bootstrap" {
  node                 = local.nodes["c-01"].ip
  client_configuration = local.client_config
  endpoint             = local.nodes["c-01"].ip
  depends_on           = [talos_machine_configuration_apply.node_config]
}

################################################################################
# 5. KUBECONFIG RETRIEVAL
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

output "kubeconfig_path" {
  value = abspath(resource.local_file.kubeconfig.filename)
}
