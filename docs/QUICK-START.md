# Quick Start: Immich Infrastructure Setup

## Prerequisites Checklist

- [ ] Talos cluster is running (1 control plane + 2 workers)
- [ ] NFS server is configured on Proxmox host
- [ ] Can access Proxmox via SSH

## Step 1: Verify NFS Configuration

SSH to your Proxmox host:

```bash
ssh root@192.168.20.1

# Check NFS exports
showmount -e localhost

# Verify exports file
cat /etc/exports
```

Expected output should include:
```
/mnt/nfs/kubernetes 192.168.20.0/24(rw,sync,no_subtree_check,no_root_squash)
```

## Step 2: Update Configuration

Edit `tal/01-apps/variables.tf` or create `tal/01-apps/terraform.tfvars`:

```hcl
nfs_server = "192.168.20.1"              # Your Proxmox host IP
nfs_path   = "/mnt/nfs/kubernetes"       # Your NFS export path
```

## Step 3: Deploy Infrastructure

```bash
cd tal/01-apps

# Initialize
tofu init

# Plan (review what will be created)
tofu plan

# Apply
tofu apply
```

This deploys:
- NFS Subdir External Provisioner
- Storage classes: `nfs`, `nfs-rwx`, `nfs-rwo`
- Namespace: `immich`

## Step 4: Verify Deployment

```bash
export KUBECONFIG=../00-infra/kubeconfig

# Check NFS provisioner pod
kubectl get pods -n kube-system -l app=nfs-subdir-external-provisioner

# Check storage classes
kubectl get storageclass

# Check namespace
kubectl get namespace immich
```

## Step 5: Test Storage

```bash
# Create test PVC
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

# Check if bound
kubectl get pvc -n immich test-pvc

# Should show STATUS: Bound

# Verify directory created on Proxmox
ssh root@192.168.20.1 "ls -la /mnt/nfs/kubernetes/"

# Clean up
kubectl delete pvc test-pvc -n immich
```

## Step 6: Deploy Immich (Separate Repository)

Now you're ready to deploy Immich! Use one of these methods:

### Option A: Helm

```bash
helm install immich immich/immich \
  --namespace immich \
  --set postgresql.persistence.storageClass=nfs-rwo \
  --set redis.persistence.storageClass=nfs-rwo \
  --set persistence.library.storageClass=nfs-rwx
```

### Option B: ArgoCD

Create an Application manifest in your GitOps repo.

### Option C: Manual Manifests

Deploy from your `immich-infra` repository.

## Storage Class Reference

| Storage Class | Access Mode | Use Case |
|--------------|-------------|----------|
| `nfs` | RWX | Default, general purpose |
| `nfs-rwx` | RWX | Shared storage (photos/videos) |
| `nfs-rwo` | RWO | Database storage |

## Troubleshooting

### NFS provisioner not starting

```bash
kubectl logs -n kube-system -l app=nfs-subdir-external-provisioner
```

### PVC stuck in Pending

```bash
kubectl describe pvc <pvc-name> -n immich
kubectl get events -n immich --sort-by='.lastTimestamp'
```

### Permission denied on NFS

On Proxmox, ensure `/etc/exports` has `no_root_squash`:

```bash
# Edit exports
nano /etc/exports

# Reload
exportfs -ra
```

## What's Next?

✅ Infrastructure is ready
✅ Storage is configured
➡️ Deploy Immich in the `immich` namespace
➡️ Configure LoadBalancer service (Cilium will assign IP from 192.168.20.220/28)
➡️ Access Immich at the assigned LoadBalancer IP

---

**Need more details?** See `docs/IMMICH-INFRASTRUCTURE-SETUP.md`
