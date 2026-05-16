#!/bin/sh

ROOTFS="$1"

setup_user_tw() {
  echo "Adding user tw..."
  chroot "$ROOTFS" useradd -s /bin/bash \
    -U -G wheel,floppy,disk,audio,video,cdrom,optical,storage,network,kvm,input,users,xbuilder,socklog,_seatd,bluetooth \
    -p '$6$3KiTJ36M60SB88NK$WrIdFeWBelIUURxbHmTWGBnIZ55o5nS.P50obw8N/Etew0OJFGn4uOujlFgPTDD67eIx4m1.HJnmgKEZFixMN0' \
    tw
}

setup_user_tw
