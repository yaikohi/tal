#!/bin/bash
# NFS Setup Verification Script for Proxmox Host
# Run this script on your Proxmox host to verify NFS configuration
# Usage: bash check-nfs-setup.sh

set -e

echo "=================================="
echo "NFS Setup Verification Script"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run as root (sudo bash check-nfs-setup.sh)${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Running as root${NC}"
echo ""

# 1. Check if NFS server is installed
echo "1. Checking NFS server installation..."
if dpkg -l | grep -q nfs-kernel-server; then
    echo -e "${GREEN}✓ nfs-kernel-server is installed${NC}"
else
    echo -e "${RED}❌ nfs-kernel-server is NOT installed${NC}"
    echo "   Install with: apt update && apt install -y nfs-kernel-server"
    exit 1
fi
echo ""

# 2. Check if NFS server is running
echo "2. Checking NFS server status..."
if systemctl is-active --quiet nfs-server; then
    echo -e "${GREEN}✓ NFS server is running${NC}"
else
    echo -e "${RED}❌ NFS server is NOT running${NC}"
    echo "   Start with: systemctl start nfs-server && systemctl enable nfs-server"
    exit 1
fi
echo ""

# 3. Check ZFS pool 'photos'
echo "3. Checking ZFS pool 'photos'..."
if zfs list | grep -q "^photos"; then
    echo -e "${GREEN}✓ ZFS pool 'photos' exists${NC}"
    zfs list | grep "^photos"
else
    echo -e "${RED}❌ ZFS pool 'photos' does NOT exist${NC}"
    echo "   Available ZFS pools:"
    zpool list
    exit 1
fi
echo ""

# 4. Check photos mount point
echo "4. Checking photos mount point..."
MOUNT_POINT=$(zfs get -H -o value mountpoint photos 2>/dev/null || echo "")
if [ -n "$MOUNT_POINT" ] && [ "$MOUNT_POINT" != "-" ]; then
    echo -e "${GREEN}✓ ZFS pool 'photos' is mounted at: ${MOUNT_POINT}${NC}"

    # Check if immich directory exists
    if [ -d "$MOUNT_POINT/immich" ]; then
        echo -e "${GREEN}✓ Directory ${MOUNT_POINT}/immich exists${NC}"
        ls -la "$MOUNT_POINT/immich"
    else
        echo -e "${YELLOW}⚠ Directory ${MOUNT_POINT}/immich does NOT exist${NC}"
        echo "   Creating directory..."
        mkdir -p "$MOUNT_POINT/immich"
        chmod 755 "$MOUNT_POINT/immich"
        echo -e "${GREEN}✓ Created ${MOUNT_POINT}/immich${NC}"
    fi
else
    echo -e "${RED}❌ Cannot determine mount point for photos${NC}"
    exit 1
fi
echo ""

# 5. Check /etc/exports
echo "5. Checking /etc/exports configuration..."
if [ -f /etc/exports ]; then
    echo -e "${GREEN}✓ /etc/exports exists${NC}"
    echo "   Current exports:"
    cat /etc/exports
    echo ""

    # Check if photos/immich is exported
    if grep -q "${MOUNT_POINT}/immich" /etc/exports; then
        echo -e "${GREEN}✓ ${MOUNT_POINT}/immich is configured in /etc/exports${NC}"
    else
        echo -e "${YELLOW}⚠ ${MOUNT_POINT}/immich is NOT configured in /etc/exports${NC}"
        echo ""
        echo "   Recommended export configuration:"
        echo "   ${MOUNT_POINT}/immich 192.168.20.0/24(rw,sync,no_subtree_check,no_root_squash)"
        echo ""
        read -p "   Would you like to add this export? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "${MOUNT_POINT}/immich 192.168.20.0/24(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
            exportfs -ra
            echo -e "${GREEN}✓ Export added and applied${NC}"
        fi
    fi
else
    echo -e "${RED}❌ /etc/exports does NOT exist${NC}"
    echo "   Creating /etc/exports..."
    echo "${MOUNT_POINT}/immich 192.168.20.0/24(rw,sync,no_subtree_check,no_root_squash)" > /etc/exports
    exportfs -ra
    echo -e "${GREEN}✓ Created /etc/exports${NC}"
fi
echo ""

# 6. Apply exports
echo "6. Applying NFS exports..."
exportfs -ra
echo -e "${GREEN}✓ Exports applied${NC}"
echo ""

# 7. Show current exports
echo "7. Current NFS exports:"
showmount -e localhost
echo ""

# 8. Check NFS ports
echo "8. Checking NFS ports..."
if netstat -tuln | grep -q ":2049"; then
    echo -e "${GREEN}✓ NFS port 2049 is listening${NC}"
else
    echo -e "${RED}❌ NFS port 2049 is NOT listening${NC}"
fi

if netstat -tuln | grep -q ":111"; then
    echo -e "${GREEN}✓ RPC port 111 is listening${NC}"
else
    echo -e "${RED}❌ RPC port 111 is NOT listening${NC}"
fi
echo ""

# 9. Check firewall (if ufw is installed)
echo "9. Checking firewall configuration..."
if command -v ufw &> /dev/null; then
    if ufw status | grep -q "Status: active"; then
        echo -e "${YELLOW}⚠ UFW firewall is active${NC}"
        echo "   NFS requires ports: 111, 2049, 20048"
        echo "   Check rules with: ufw status verbose"
    else
        echo -e "${GREEN}✓ UFW firewall is inactive${NC}"
    fi
else
    echo -e "${GREEN}✓ UFW not installed (likely using iptables or no firewall)${NC}"
fi
echo ""

# 10. Test mount from localhost
echo "10. Testing NFS mount from localhost..."
TEST_MOUNT="/tmp/nfs-test-mount-$$"
mkdir -p "$TEST_MOUNT"

if mount -t nfs localhost:${MOUNT_POINT}/immich "$TEST_MOUNT" 2>/dev/null; then
    echo -e "${GREEN}✓ Successfully mounted NFS share locally${NC}"
    ls -la "$TEST_MOUNT"
    umount "$TEST_MOUNT"
    rmdir "$TEST_MOUNT"
else
    echo -e "${RED}❌ Failed to mount NFS share locally${NC}"
    rmdir "$TEST_MOUNT"
fi
echo ""

# 11. Check network connectivity
echo "11. Checking network configuration..."
echo "   Proxmox host IP addresses:"
ip addr show | grep "inet " | grep -v 127.0.0.1
echo ""

# Summary
echo "=================================="
echo "Summary"
echo "=================================="
echo ""
echo "NFS Server: ${MOUNT_POINT}/immich"
echo "Network: 192.168.20.0/24"
echo ""
echo "To test from a Kubernetes node, run:"
echo "  talosctl -n 192.168.20.21 shell"
echo "  mount -t nfs 192.168.20.1:${MOUNT_POINT}/immich /mnt"
echo ""
echo -e "${GREEN}✓ NFS setup verification complete${NC}"
echo ""
echo "If you made changes, restart the NFS provisioner pod:"
echo "  kubectl delete pod -n kube-system -l app=nfs-subdir-external-provisioner"
