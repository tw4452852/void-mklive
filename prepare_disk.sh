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
sfdisk -a $DISK <<EOF
,,L,
EOF

udevadm trigger --name-match=$DISK >/dev/null 2>&1
partprobe >/dev/null 2>&1
sleep 3

# Reformat part1 as ext4
PART1=$(get_disk_part_name $DISK 1)
mkfs.ext4 -F $PART1

PART3=$(get_disk_part_name $DISK 3)
mkfs.ext4 -F -L data $PART3

# Necessary directories and files
mount $PART3 /mnt

mkdir -p /mnt/docker
cat << 'EOF' > /mnt/rc.local
#!/bin/sh

# Persist docker containers and volumes
mkdir -p /etc/docker
cat << 'EOF' > /etc/docker/daemon.json
{
  "data-root": "/mnt/data/docker"
}

EOF
chmod +x /mnt/rc.local

uuid1="$(blkid -s UUID -o value $PART1)"
cat << EOF > /mnt/rc.shutdown
#!/bin/sh

dm1="\$(blkid | grep $uuid1 | grep /dev/mapper | cut -d':' -f1)"

mount \$dm1 /mnt

if [ -e /mnt/new.iso ]; then
    [ -e /mnt/tw-void.iso ] && mv -v /mnt/tw-void.iso /mnt/old.iso
    mv -v /mnt/new.iso /mnt/tw-void.iso
fi

umount /mnt

EOF
chmod +x /mnt/rc.shutdown

mkdir -p /mnt/home
install -d -o tw -g tw /mnt/home/tw
sudo --user tw sh -c ' \
  cd /mnt/home/tw && \
  git init && \
  git remote add origin https://github.com/tw4452852/MyConfig && \
  git fetch && \
  git checkout -ft origin/master && \
  git config status.showUntrackedFiles no \
'
umount /mnt
