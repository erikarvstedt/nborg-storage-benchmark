#!/usr/bin/env bash
set -euxo pipefail

disk1=/dev/sda
disk2=/dev/sdb
# `swapSize` should equal system RAM.
# This setup will create one swap partition on each disk.
swapSize=${swapSize:-32GiB}

if zpool list rpool &>/dev/null; then
    zpool export rpool
fi

formatDisk() {
  disk=$1
  sgdisk --zap-all \
   -n 0:0:+$swapSize -t 0:8200 -c 0:swap \
   -n 0:0:+200GiB    -t 0:8300 -c 0:tmp \
   -n 0:0:+200GiB    -t 0:bf01 -c 0:zfs \
   -n 0:0:+200GiB    -t 0:8300 -c 0:btrfs \
   -n 0:0:+200GiB    -t 0:8300 -c 0:ext4 \
   $disk
}
formatDisk $disk1
formatDisk $disk2
mkswap -L swap1 ${disk1}1
mkswap -L swap2 ${disk2}1

# ashift=12
# Set pool sector size to 2^12 to optimize performance for storage devices with 4K sectors.
# Auto-detection of physical sector size (/sys/block/sdX/queue/physical_block_size) can be unreliable.
#
# acltype=posixacl
# Required for / and the systemd journal
#
# xattr=sa
# Improve performance of certain extended attributes
#
# normalization=formD
# Enable UTF-8 normalization for file names
#
zpool create -f \
  -o ashift=12 \
  -O acltype=posixacl \
  -O xattr=sa \
  -O normalization=formD \
  -O relatime=on \
  -O compression=lz4 \
  -O dnodesize=auto \
  rpool mirror ${disk1}3 ${disk2}3

zfs create -o mountpoint=legacy rpool/root
