#!/bin/bash

set -e

my_bootstrap_packages=(
  git
  parted
)

my_bootstrap_services=(
  acpid
  dhcpcd
  sshd
  wpa_supplicant
)

my_packages=(
  Bear
  alacritty
  avahi
  avahi-utils
  caddy
  carapace
  cronie
  curl
  dbus
  dejavu-fonts-ttf
  dmenu
  docker
  dust
  elvish
  fcitx5
  fcitx5-chinese-addons
  fcitx5-configtool
  fcitx5-gtk
  fcitx5-gtk+3
  fcitx5-qt
  fd
  flatpak
  fontconfig
  foot
  fuzzel
  fzf
  git
  go
  gopls
  grim
  htop
  jq
  jujutsu
  kak-lsp
  kakoune
  lsof
  lswt
  lz4
  nss-mdns
  openresolv
  pamixer
  parted
  pass
  pipewire
  pkg-config
  psmisc
  qemu
  qutebrowser
  ripgrep
  river
  rsync
  sdcv
  seatd
  sioyek
  slurp
  socklog-void
  strace
  tio
  tiramisu
  tmux
  trace-cmd
  vim
  vmtouch
  waylock
  wdisplays
  wget
  wireplumber
  wl-clipboard
  wlrctl
  wmctrl
  wpa_gui
  wqy-microhei
  xclip
  xdg-utils
  xsel
  xtools
  xz
  zip
)

my_services=(
  acpid
  avahi-daemon
  cronie
  dbus
  dhcpcd
  docker
  nanoklogd
  seatd
  socklog-unix
  sshd
  wpa_supplicant
)

my_kernel_cmdline="loglevel=4 nvidia_drm.modeset=1 transparent_hugepage=always"

trap 'rm -fr ./inc' INT TERM 0

# runsvdir for tw
mkdir -p ./inc/etc/sv/runsvdir-tw
cat << 'EOF' >> ./inc/etc/sv/runsvdir-tw/run
#!/bin/sh

export USER="tw"
export HOME="/home/tw"

groups="$(id -Gn "$USER" | tr ' ' ':')"
svdir="$HOME/service"

exec chpst -u "$USER:$groups" runsvdir "$svdir"
EOF
chmod +x ./inc/etc/sv/runsvdir-tw/run
mkdir -p ./inc/etc/runit/runsvdir/default
ln -s /etc/sv/runsvdir-tw ./inc/etc/runit/runsvdir/default/

# sudo w/o password for wheel group 
mkdir -p ./inc/etc/sudoers.d/
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > ./inc/etc/sudoers.d/wheel

# mount data disk
mkdir -p ./inc/mnt/data
cat << 'EOF' >> ./inc/etc/fstab
tmpfs 			/tmp 		tmpfs 	defaults,nosuid,nodev 	0 0
LABEL=data 		/mnt/data 	ext4 	defaults,nofail 			0 0
/mnt/data/home   	/home    		none   	defaults,bind,nofail   	0 0
EOF

# run user's rc.local
cat << 'EOF' > ./inc/etc/rc.local
#!/bin/sh

mount --make-rshared /

[ -x /mnt/data/rc.local ] && /mnt/data/rc.local
EOF
chmod +x ./inc/etc/rc.local

# Timezone: Asia/Shanghai
ln -sf /usr/share/zoneinfo/Asia/Shanghai ./inc/etc/localtime

# Include ourselves
if [ -d .git ]; then
  mkdir -p ./inc/extra
  git bundle create ./inc/extra/void-mklive.git.bundle HEAD
fi

# Use environment _BS to build bootstrap iso
function _packages() {
  if [ -n "${_BS}" ] ;then
    echo "${my_bootstrap_packages[*]}"
  else
    echo "${my_packages[*]}"
  fi
}

function _services() {
  if [ -n "${_BS}" ] ;then
    echo "${my_bootstrap_services[*]}"
  else
    echo "${my_services[*]}"
  fi
}

[ -f "tw-void.iso" ] && mv tw-void.iso old_tw-void.iso

./mklive.sh \
  -T "Tw voidlinux" \
  -p "$(_packages)" \
  -e "/bin/bash" \
  -S "$(_services)" \
  -C "${my_kernel_cmdline}" \
  -I inc \
  -o "tw-void.iso" \
  "$@"