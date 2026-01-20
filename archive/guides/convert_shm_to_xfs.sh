#!/bin/bash

# Script to convert /dev/shm from tmpfs to xfs filesystem
# This script requires sudo privileges

set -e

echo "=== Converting /dev/shm from tmpfs to xfs ==="

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with sudo privileges"
    echo "Usage: sudo ./convert_shm_to_xfs.sh"
    exit 1
fi

# Step 1: Check current /dev/shm status
echo "Step 1: Checking current /dev/shm status..."
mount | grep shm || echo "No /dev/shm mount found"

# Step 2: Unmount current tmpfs /dev/shm
echo "Step 2: Unmounting current tmpfs /dev/shm..."
if mount | grep -q "/dev/shm"; then
    umount /dev/shm
    echo "Successfully unmounted /dev/shm"
else
    echo "/dev/shm is not currently mounted"
fi

# Step 3: Check available space in LVM
echo "Step 3: Checking available space in LVM..."
vgdisplay ubuntu-vg | grep "Free PE" || echo "Checking LVM status..."

# Step 4: Create a new logical volume for shm
echo "Step 4: Creating new logical volume for shm..."
# Create a 10GB logical volume (adjust size as needed)
lvcreate -L 10G -n shm-lv ubuntu-vg
echo "Created logical volume: /dev/ubuntu-vg/shm-lv"

# Step 5: Format the new logical volume with xfs
echo "Step 5: Formatting logical volume with xfs..."
mkfs.xfs /dev/ubuntu-vg/shm-lv
echo "Formatted /dev/ubuntu-vg/shm-lv with xfs"

# Step 6: Mount the new xfs filesystem to /dev/shm
echo "Step 6: Mounting xfs filesystem to /dev/shm..."
mount /dev/ubuntu-vg/shm-lv /dev/shm
echo "Mounted xfs filesystem to /dev/shm"

# Step 7: Update /etc/fstab for permanent mounting
echo "Step 7: Updating /etc/fstab for permanent mounting..."
# Backup original fstab
cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)

# Add new entry to fstab
echo "/dev/ubuntu-vg/shm-lv /dev/shm xfs defaults 0 0" >> /etc/fstab
echo "Added entry to /etc/fstab"

# Step 8: Verify the new setup
echo "Step 8: Verifying new setup..."
echo "Mount status:"
mount | grep shm
echo ""
echo "Disk usage:"
df -h | grep shm
echo ""
echo "Filesystem type:"
file -s /dev/shm

echo ""
echo "=== Conversion completed successfully ==="
echo "Note: You may need to restart applications that use /dev/shm"
echo "The original tmpfs configuration has been replaced with xfs"
