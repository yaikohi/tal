# NFS Troubleshooting Guide

## Current Issue

The NFS provisioner pod is failing to mount with error:
```
mount.nfs: Connection refused
```

This means the Kubernetes worker nodes cannot connect to your Proxmox NFS server.

## Your Configuration

- **NFS Server**: 192.168.20.1 (Proxmox host)
- **NFS Path**: /photos/immich
- **ZFS Pool**: photos
- **ZFS Directory**: immich
- **Client Network**: 192.168.20.0/24

## Step-by-Step Fix

### 1. Verify ZFS Pool Mount Point

SSH to your Proxmox host:

```bash
ssh root@192.168.20.1

# Check where 'photos' is mounted
zfs list | grep photos
zfs get mountpoint photos
```

The output will show something like:
```
photos  1.0T  /photos  (or /mnt/photos)
```

Note this path - you'll need it for the next steps.

### 2. Create Immich Directory

```bash
# If photos is mounted at /photos
mkdir -p /photos/immich
chmod 755 /photos/immich

# OR if photos is mounted at /mnt/photos
mkdir -p /mnt/photos/immich
chmod 755 /mnt/photos/immich
```

### 3. Install NFS Server (if not already installed)

```bash
# Check if installed
dpkg -l | grep nfs-kernel-server

# If not installed:
apt update
apt install -y nfs-kernel-server
```

### 4. Configure NFS Export

Edit `/etc/exports`:

```bash
nano /etc/exports
```

Add this line (adjust path to match your ZFS mount point):

```
/photos/immich 192.168.20.0/24(rw,sync,no_subtree_check,no_root_squash)
```

**Important options explained:**
- `rw` - Read-write access
- `sync` - Synchronous writes (safer)
- `no_subtree_check` - Better performance
- `no_root_squash` - **REQUIRED** - Allows Kubernetes to manage files as root
- `192.168.20.0/24` - Allows entire cluster subnet

### 5. Apply NFS Configuration

```bash
# Reload exports
exportfs -ra

# Enable and restart NFS server
systemctl enable nfs-server
systemctl restart nfs-server

# Verify it's running
systemctl status nfs-server

# Check exports are active
showmount -e localhost
```

Expected output:
```
Export list for localhost:
/photos/immich 192.168.20.0/24
```

### 6. Verify NFS Ports Are Open

```bash
# Check NFS is listening
netstat -tuln | grep 2049   # NFS port
netstat -tuln | grep 111    # RPC port

# If you have a firewall, allow NFS:
# For UFW:
ufw allow from 192.168.20.0/24 to any port nfs
ufw allow from 192.168.20.0/24 to any port 111
ufw allow from 192.168.20.0/24 to any port 2049

# For iptables:
iptables -A INPUT -s 192.168.20.0/24 -p tcp --dport 2049 -j ACCEPT
iptables -A INPUT -s 192.168.20.0/24 -p tcp --dport 111 -j ACCEPT
iptables -A INPUT -s 192.168.20.0/24 -p udp --dport 111 -j ACCEPT
```

### 7. Test Mount from Proxmox Itself

```bash
# Create test mount point
mkdir -p /tmp/nfs-test

# Try to mount locally
mount -t nfs localhost:/photos/immich /tmp/nfs-test

# If successful, check it
ls -la /tmp/nfs-test

# Unmount
umount /tmp/nfs-test
rmdir /tmp/nfs-test
```

If this fails, your NFS server configuration has issues.

### 8. Update Kubernetes Configuration (if path is different)

If your ZFS pool is mounted at a different location (e.g., `/mnt/photos` instead of `/photos`), update the Terraform configuration:

Edit `tal/01-apps/terraform.tfvars`:

```hcl
nfs_server = "192.168.20.1"
nfs_path   = "/mnt/photos/immich"  # Update to match your actual path
```

Then reapply:

```bash
cd tal/01-apps
tofu apply
```

### 9. Restart NFS Provisioner Pod

After fixing NFS on Proxmox, restart the provisioner pod:

```bash
export KUBECONFIG=../00-infra/kubeconfig
kubectl delete pod -n kube-system -l app=nfs-subdir-external-provisioner
```

Watch it start:

```bash
kubectl get pods -n kube-system -w
```

### 10. Verify NFS Provisioner Is Working

Check pod logs:

```bash
kubectl logs -n kube-system -l app=nfs-subdir-external-provisioner
```

You should see:
```
I0213 13:55:13.123456       1 main.go:52] Starting nfs-subdir-external-provisioner
I0213 13:55:13.234567       1 controller.go:823] Starting provisioner controller
```

No mount errors.

## Test Storage Provisioning

Create a test PVC:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-pvc
  namespace: immich
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs
  resources:
    requests:
      storage: 1Gi
EOF
```

Check if it's bound:

```bash
kubectl get pvc -n immich test-nfs-pvc
```

Should show:
```
NAME           STATUS   VOLUME     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
test-nfs-pvc   Bound    pvc-xxx    1Gi        RWX            nfs            5s
```

Verify directory was created on Proxmox:

```bash
# On Proxmox
ls -la /photos/immich/
```

You should see a directory like `immich-test-nfs-pvc-pvc-xxx`

Clean up test:

```bash
kubectl delete pvc test-nfs-pvc -n immich
```

## Common Issues

### Issue: "Connection refused"

**Cause**: NFS server not running or not configured

**Fix**:
```bash
systemctl start nfs-server
systemctl enable nfs-server
exportfs -ra
```

### Issue: "Permission denied"

**Cause**: Missing `no_root_squash` in exports

**Fix**: Add `no_root_squash` to `/etc/exports`:
```
/photos/immich 192.168.20.0/24(rw,sync,no_subtree_check,no_root_squash)
```

Then:
```bash
exportfs -ra
```

### Issue: "No route to host"

**Cause**: Firewall blocking NFS ports

**Fix**: Allow ports 111, 2049, and 20048 from 192.168.20.0/24

### Issue: "Stale file handle"

**Cause**: NFS export changed while mounted

**Fix**:
```bash
# On Proxmox
exportfs -ra
systemctl restart nfs-server

# In Kubernetes
kubectl delete pod -n kube-system -l app=nfs-subdir-external-provisioner
```

### Issue: Wrong path - "/photos" vs "/mnt/photos"

**Check**: 
```bash
zfs get mountpoint photos
```

**Fix**: Update `tal/01-apps/terraform.tfvars` with correct path

## Verification Checklist

- [ ] ZFS pool 'photos' exists and is mounted
- [ ] Directory /photos/immich (or /mnt/photos/immich) exists
- [ ] nfs-kernel-server is installed
- [ ] NFS server is running (systemctl status nfs-server)
- [ ] /etc/exports has correct path with no_root_squash
- [ ] exportfs -ra has been run
- [ ] showmount -e localhost shows the export
- [ ] Port 2049 is listening (netstat -tuln | grep 2049)
- [ ] Firewall allows NFS from 192.168.20.0/24
- [ ] Can mount locally: mount -t nfs localhost:/photos/immich /mnt
- [ ] NFS provisioner pod is running
- [ ] Test PVC can be created and bound

## Quick Setup Script

Save this as `setup-nfs.sh` and run on Proxmox:

```bash
#!/bin/bash
# Quick NFS setup for Immich on Proxmox

# Get ZFS mount point
MOUNT=$(zfs get -H -o value mountpoint photos)
echo "ZFS 'photos' is mounted at: $MOUNT"

# Create directory
mkdir -p $MOUNT/immich
chmod 755 $MOUNT/immich
echo "Created $MOUNT/immich"

# Install NFS if needed
if ! dpkg -l | grep -q nfs-kernel-server; then
    apt update && apt install -y nfs-kernel-server
fi

# Add to exports if not already there
if ! grep -q "$MOUNT/immich" /etc/exports; then
    echo "$MOUNT/immich 192.168.20.0/24(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    echo "Added export to /etc/exports"
fi

# Apply
exportfs -ra
systemctl enable nfs-server
systemctl restart nfs-server

# Show status
echo "================================"
echo "NFS Setup Complete!"
echo "================================"
showmount -e localhost
systemctl status nfs-server --no-pager
```

## Next Steps

Once NFS is working:

1. Storage classes will be created automatically
2. Deploy Immich using the `nfs` storage class
3. PostgreSQL and Redis can use `nfs-rwo` for better performance
4. Immich photo storage should use `nfs-rwx` for shared access

## Getting Help

If you're still stuck after following this guide:

1. Check Proxmox NFS logs: `journalctl -u nfs-server -f`
2. Check NFS provisioner logs: `kubectl logs -n kube-system -l app=nfs-subdir-external-provisioner`
3. Verify network connectivity: `ping 192.168.20.1` from a worker node
4. Check Talos system logs: `talosctl -n 192.168.20.21 dmesg | grep -i nfs`
