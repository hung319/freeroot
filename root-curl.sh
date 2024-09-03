#!/bin/sh

ROOTFS_DIR=$(pwd)
export PATH=$PATH:~/.local/usr/bin
max_retries=50
timeout=1
ARCH=$(uname -m)

if [ "$ARCH" = "x86_64" ]; then
  ARCH_ALT=amd64
elif [ "$ARCH" = "aarch64" ]; then
  ARCH_ALT=arm64
else
  printf "Unsupported CPU architecture: ${ARCH}"
  exit 1
fi

if [ ! -e $ROOTFS_DIR/.installed ]; then
  echo "#######################################################################################"
  echo "#"
  echo "#                                      Foxytoux INSTALLER"
  echo "#"
  echo "#                           Copyright (C) 2024, RecodeStudios.Cloud"
  echo "#"
  echo "#"
  echo "#######################################################################################"

  read -p "Do you want to install Ubuntu? (y/n): " install_ubuntu
fi

case $install_ubuntu in
  [y])
    curl -L --retry $max_retries --connect-timeout $timeout -o /tmp/rootfs.tar.gz \
      "http://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04-base-${ARCH_ALT}.tar.gz"
    tar -xf /tmp/rootfs.tar.gz -C $ROOTFS_DIR
    ;;
  *)
    echo "Skipping Ubuntu installation."
    ;;
esac

if [ ! -e $ROOTFS_DIR/.installed ]; then
  mkdir $ROOTFS_DIR/usr/local/bin -p
  curl -L --retry $max_retries --connect-timeout $timeout -o $ROOTFS_DIR/usr/local/bin/proot "https://raw.githubusercontent.com/hung319/freeroot/main/proot-${ARCH}"

  while [ ! -s "$ROOTFS_DIR/usr/local/bin/proot" ]; do
    rm $ROOTFS_DIR/usr/local/bin/proot -rf
    curl -L --retry $max_retries --connect-timeout $timeout -o $ROOTFS_DIR/usr/local/bin/proot "https://raw.githubusercontent.com/hung319/freeroot/main/proot-${ARCH}"

    if [ -s "$ROOTFS_DIR/usr/local/bin/proot" ]; then
      chmod 755 $ROOTFS_DIR/usr/local/bin/proot
      break
    fi

    chmod 755 $ROOTFS_DIR/usr/local/bin/proot
    sleep 1
  done

  chmod 755 $ROOTFS_DIR/usr/local/bin/proot
fi

if [ ! -e $ROOTFS_DIR/.installed ]; then
  printf "nameserver 1.1.1.1\nnameserver 1.0.0.1" > ${ROOTFS_DIR}/etc/resolv.conf
  rm -rf /tmp/rootfs.tar.xz /tmp/sbin
  touch $ROOTFS_DIR/.installed

  # Update sources.list for Ubuntu 22.04
  cat << EOF > ${ROOTFS_DIR}/etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
EOF

  # Create a script to update keys and perform initial setup
  cat << EOF > ${ROOTFS_DIR}/root/init_setup.sh
#!/bin/bash
set -e

# Update and install necessary packages
apt-get update
apt-get install -y gnupg ca-certificates wget

# Add the Ubuntu archive keyring
wget -O /etc/apt/trusted.gpg.d/ubuntu-archive-keyring.gpg https://archive.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg

# Add specific keys
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 871920D1991BC93C
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32

# Update package lists
apt-get update

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF

  chmod +x ${ROOTFS_DIR}/root/init_setup.sh
fi

CYAN='\e[0;36m'
WHITE='\e[0;37m'
RESET_COLOR='\e[0m'

display_gg() {
  echo -e "${WHITE}___________________________________________________${RESET_COLOR}"
  echo -e ""
  echo -e "           ${CYAN}-----> Mission Completed ! <----${RESET_COLOR}"
  echo -e ""
  echo -e "Please run './root/init_setup.sh' after entering the proot environment to complete the setup."
}

clear
display_gg

$ROOTFS_DIR/usr/local/bin/proot \
  --rootfs="${ROOTFS_DIR}" \
  -0 -w "/root" -b /dev -b /sys -b /proc -b /etc/resolv.conf --kill-on-exit
