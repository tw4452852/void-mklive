#!/bin/bash

set -eu


function get_disk_part_name() {
    DISK=$1
    
    if echo $DISK | grep -q "/dev/loop"; then
        echo ${DISK}p${2}
    elif echo $DISK | grep -q "/dev/nvme[0-9][0-9]*n[0-9]"; then
        echo ${DISK}p${2}
    elif echo $DISK | grep -q "/dev/mmcblk[0-9]"; then
        echo ${DISK}p${2}
    elif echo $DISK | grep -q "/dev/nbd[0-9]"; then
        echo ${DISK}p${2}
    elif echo $DISK | grep -q "/dev/zd[0-9]"; then
        echo ${DISK}p${2}
    elif echo $DISK | grep -q "/dev/md[0-9]"; then
        echo ${DISK}p${2}
    else
        echo ${DISK}${2}
    fi
}

VENTOY_DIR=/tmp/ventoy
DISK=$1

disk_sector_num=$(cat /sys/block/${DISK#/dev/}/size)
disk_size_gb=$(( $disk_sector_num / 2097152 ))
reserved_size_gb=$(( $disk_size_gb - 16 )) # Reserve 16G for part1 (to save iso) and part2 (Ventoy)

mkdir -p $VENTOY_DIR
VENTOY_SH=$(find $VENTOY_DIR -name Ventoy2Disk.sh)
if [ -z "$VENTOY_SH" ] ; then
  echo "Decompress ventoy ($(dirname $0)/extra/ventoy-*.tar.gz) ..."
  tar xzf $(dirname $0)/extra/ventoy-*.tar.gz -C $VENTOY_DIR
fi
VENTOY_SH=$(find $VENTOY_DIR -name Ventoy2Disk.sh)

sh $VENTOY_SH -I -r $(( $reserved_size_gb * 1024 )) $DISK <<EOF
y
y
EOF

echo "Create partion3 for data, size: $reserved_size_gb G..."
fdisk $DISK <<EOF
n
p
3
 
-0
w
EOF

udevadm trigger --name-match=$DISK >/dev/null 2>&1
partprobe >/dev/null 2>&1
sleep 3

# Reformat part1 as ext4
mkfs.ext4 $(get_disk_part_name $DISK 1)

PART3=$(get_disk_part_name $DISK 3)
mkfs.ext4 -L data $PART3

# Necessary directories and files
mount $PART3 /mnt
touch /mnt/rc.local
chmod +x /mnt/rc.local
mkdir -p /mnt/home
install -d -o tw -g tw /mnt/home/tw
umount /mnt
