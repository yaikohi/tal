# Immich Infrastructure Setup Guide

This guide walks you through setting up the infrastructure required for Immich (PostgreSQL, Redis, and shared storage) on your Talos Kubernetes cluster.

## Overview

Your setup:
- **Talos Cluster**: `yaya` with 1 control plane (192.168.20.11) and 2 workers (192.168.20.21, 192.168.20.22)
- **Network**: 192.168.20.0/24
- **Proxmox Host**: Likely 192.168.20.1 (your gateway)
- **NFS Server**: Running on Proxmox host
- **LoadBalancer Range**: 192.168.20.220/28 (via Cilium)

## Prerequisites

### 1. Verify NFS Server Configuration

SSH into your Proxmox host and check your NFS exports:

```bash
# Check what's exported
showmount -e localhost

# View exports configuration
cat /etc/exports
```

You should see something like:
```
/mnt/nfs/kubernetes 192.168.20.0/24(rw,sync,no_subtree_check,no_root_squash)
```

**Important settings:**
- `rw` - Read-write access
- `no_root_squash` - Required for Kubernetes to manage files
- `192.168.20.0/24` - Allows your entire cluster subnet

If your NFS export is different, update the path in `tal/01-apps/variables.tf`.

### 2. Test NFS from a Talos Node

Verify connectivity from one of your nodes:

```bash
# SSH to your control plane node
talosctl -n 192.168.20.11 shell

# Inside the node, test NFS mount (if nfs-utils are available)
# Note: Talos is minimal, so this might not work directly
# The NFS provisioner will handle this for you
```

## Infrastructure Components

### What Gets Deployed

When you apply the Terraform/OpenTofu configuration, it will set up:

1. **NFS Subdir External Provisioner**
   - Deployed in `kube-system` namespace
   - Automatically creates directories on your NFS share for each PVC
   - Handles dynamic provisioning of persistent volumes

2. **Storage Classes**
   - `nfs` (default): General purpose storage
   - `nfs-rwx`: ReadWriteMany - for shared storage (e.g., Immich photos/videos)
   - `nfs-rwo`: ReadWriteOnce - for database storage with WaitForFirstConsumer binding

3. **Namespace**
   - `immich`: Pre-created namespace for your Immich deployment

### Storage Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Proxmox Host (NFS Server)                 │
│                      192.168.20.1                            │
│                                                              │
│  /mnt/nfs/kubernetes/                                        │
│    ├── immich-pvc-photos/          (RWX - shared)          │
│    ├── postgres-pvc-data/          (RWO - single node)     │
│    └── redis-pvc-data/             (RWO - single node)     │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ NFS v3/v4
                            │
    ┌───────────────────────┼───────────────────────┐
    │                       │                       │
┌───▼────┐            ┌─────▼───┐            ┌─────▼───┐
│ c-01   │            │  w-01   │            │  w-02   │
│ .11    │            │  .21    │            │  .22    │
└────────┘            └─────────┘            └─────────┘
   Talos Cluster Nodes (192.168.20.x/24)
```

## Deployment Steps

### Step 1: Configure Variables

Edit `tal/01-apps/variables.tf` or create a `terraform.tfvars` file:

```hcl
# tal/01-apps/terraform.tfvars
nfs_server = "192.168.20.1"              # Your Proxmox host IP
nfs_path   = "/mnt/nfs/kubernetes"       # Your NFS export path
```

### Step 2: Initialize and Apply

```bash
cd tal/01-apps

# Initialize Terraform/OpenTofu
tofu init

# Review the plan
tofu plan

# Apply the configuration
tofu apply
```

This will:
- Deploy Cilium CNI with LoadBalancer support
- Install the NFS provisioner
- Create storage classes
- Create the `immich` namespace
- Deploy ArgoCD (if included)

### Step 3: Verify Deployment

```bash
# Set kubeconfig
export KUBECONFIG=../00-infra/kubeconfig

# Check NFS provisioner
kubectl get pods -n kube-system | grep nfs

# Check storage classes
kubectl get storageclass

# Should show:
# nfs (default)
# nfs-rwx
# nfs-rwo

# Check namespace
kubectl get namespace immich
```

### Step 4: Test Storage Provisioning

Create a test PVC to verify NFS is working:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: immich
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-rwx
  resources:
    requests:
      storage: 1Gi
EOF

# Check if PVC is bound
kubectl get pvc -n immich test-pvc

# Check on your Proxmox NFS server - a directory should be created
# SSH to Proxmox: ls -la /mnt/nfs/kubernetes/

# Clean up test
kubectl delete pvc test-pvc -n immich
```

## Storage Class Usage Guide

### For Immich Components

When you deploy Immich (via Helm, ArgoCD, or manually):

**PostgreSQL:**
```yaml
persistence:
  storageClass: nfs-rwo  # Single-node access, better performance
  size: 10Gi
```

**Redis:**
```yaml
persistence:
  storageClass: nfs-rwo  # Or use emptyDir for ephemeral
  size: 1Gi
```

**Immich (Photo/Video Storage):**
```yaml
persistence:
  library:
    storageClass: nfs-rwx  # Shared access across multiple pods
    size: 100Gi            # Adjust based on your needs
```

## Next Steps: Deploying Immich

Now that the infrastructure is ready, you can deploy Immich using one of these methods:

### Option 1: Helm (Recommended)

```bash
# Add Immich Helm repository (if available)
helm repo add immich https://immich-app.github.io/immich-charts
helm repo update

# Deploy Immich
helm install immich immich/immich \
  --namespace immich \
  --set postgresql.persistence.storageClass=nfs-rwo \
  --set redis.persistence.storageClass=nfs-rwo \
  --set persistence.library.storageClass=nfs-rwx
```

### Option 2: ArgoCD Application

Create an ArgoCD Application manifest in your GitOps repository:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: immich
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://immich-app.github.io/immich-charts
    targetRevision: <version>
    chart: immich
    helm:
      values: |
        postgresql:
          persistence:
            storageClass: nfs-rwo
            size: 10Gi
        redis:
          persistence:
            storageClass: nfs-rwo
            size: 1Gi
        persistence:
          library:
            storageClass: nfs-rwx
            size: 100Gi
  destination:
    server: https://kubernetes.default.svc
    namespace: immich
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=false
```

### Option 3: Manual Kubernetes Manifests

Create your own manifests in a separate repository (e.g., `immich-infra`).

## Troubleshooting

### NFS Mount Issues

If pods can't mount NFS volumes:

```bash
# Check provisioner logs
kubectl logs -n kube-system -l app=nfs-subdir-external-provisioner

# Common issues:
# 1. Firewall blocking NFS ports (2049, 111)
# 2. NFS export permissions (need no_root_squash)
# 3. Network connectivity between cluster and NFS server
```

### Test NFS from Proxmox

```bash
# On Proxmox host
systemctl status nfs-server
exportfs -v

# Check if NFS is listening
netstat -tulpn | grep 2049
```

### Permission Issues

If you get permission denied errors:

```bash
# On Proxmox, check the export options
cat /etc/exports

# Ensure you have:
# - no_root_squash (allows root user from client)
# - rw (read-write access)

# After changing /etc/exports:
exportfs -ra
```

### Storage Not Provisioning

```bash
# Check events
kubectl get events -n immich --sort-by='.lastTimestamp'

# Check PVC status
kubectl describe pvc <pvc-name> -n immich

# Check storage class
kubectl describe storageclass nfs
```

## Security Considerations

1. **Network Isolation**: Your NFS server only accepts connections from 192.168.20.0/24
2. **Backup Strategy**: NFS data is on your Proxmox host - ensure you have backups
3. **Access Control**: The `immich` namespace is isolated
4. **Reclaim Policy**: Set to "Retain" by default - deleted PVCs are archived, not deleted

## Performance Notes

- **NFS Performance**: Good for photos/videos (large sequential reads/writes)
- **Database Performance**: Consider NVMe-backed storage for production databases
- **Network**: 1Gbps+ recommended between nodes and NFS server
- **For Better Performance**: Consider Longhorn or Rook-Ceph for block storage (future enhancement)

## Monitoring NFS Usage

```bash
# Check PV usage
kubectl get pv

# Check disk usage on NFS server (from Proxmox)
du -sh /mnt/nfs/kubernetes/*

# Monitor with df
df -h /mnt/nfs/kubernetes
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         User Access                          │
│                  http://immich.local:2283                    │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │   Cilium LoadBalancer │
                  │   192.168.20.220/28   │
                  └──────────┬────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼─────┐        ┌────▼─────┐        ┌────▼─────┐
   │  Immich  │        │  Immich  │        │  Immich  │
   │  Server  │        │  Server  │        │  Server  │
   │   Pod    │        │   Pod    │        │   Pod    │
   └────┬─────┘        └────┬─────┘        └────┬─────┘
        │                   │                    │
        └───────────────────┼────────────────────┘
                            │
          ┌─────────────────┴─────────────────┐
          │                                   │
     ┌────▼──────┐                      ┌────▼──────┐
     │ PostgreSQL│                      │   Redis   │
     │  (RWO)    │                      │  (RWO)    │
     └────┬──────┘                      └────┬──────┘
          │                                   │
          └───────────────┬───────────────────┘
                          │
                    ┌─────▼──────┐
                    │ NFS Storage│
                    │   (RWX)    │
                    │   Photos/  │
                    │   Videos   │
                    └────────────┘
                          │
                          ▼
              ┌──────────────────────┐
              │  Proxmox NFS Server  │
              │    192.168.20.1      │
              │ /mnt/nfs/kubernetes  │
              └──────────────────────┘
```

## Summary

After completing this setup:
- ✅ NFS provisioner is running
- ✅ Storage classes are configured
- ✅ `immich` namespace is created
- ✅ Dynamic storage provisioning is enabled
- ✅ Ready to deploy Immich with PostgreSQL and Redis

You can now proceed to deploy Immich in the `immich` namespace using your preferred method (Helm, ArgoCD, or manual manifests) without needing to define the infrastructure in OpenTofu.