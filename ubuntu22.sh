#!/bin/bash

ROOTFS_DIR=$(pwd)
export PATH=$PATH:~/.local/usr/bin
max_retries=50
timeout=10
ARCH=$(uname -m)
PROOT_VERSION="5.3.0"

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

  echo "Installing Ubuntu 22.04..."

  make --version
  url="https://fra1lxdmirror01.do.letsbuildthe.cloud/images/ubuntu/jammy/${ARCH_ALT}/default/"
  LATEST_VERSION=$(curl -s $url | grep -oP 'href="\K[^"]+/' | sort -r | head -n 1)
  curl -Ls "${url}${LATEST_VERSION}/rootfs.tar.xz" -o $ROOTFS_DIR/rootfs.tar.xz

  echo "Extracting rootfs..."
  # Manually decompress .xz file
  ( \
    dd if=$ROOTFS_DIR/rootfs.tar.xz bs=1 count=6 2>/dev/null | od -An -tx1 | tr -d ' \n' | grep -q 'fd377a585a00' && \
    dd if=$ROOTFS_DIR/rootfs.tar.xz bs=1 skip=12 2>/dev/null | xz -dc > $ROOTFS_DIR/rootfs.tar \
  ) || ( \
    dd if=$ROOTFS_DIR/rootfs.tar.xz bs=1 count=2 2>/dev/null | od -An -tx1 | tr -d ' \n' | grep -q '1f8b' && \
    dd if=$ROOTFS_DIR/rootfs.tar.xz bs=1 skip=10 2>/dev/null | gzip -dc > $ROOTFS_DIR/rootfs.tar \
  )

  tar -xf $ROOTFS_DIR/rootfs.tar -C "$ROOTFS_DIR"

  mkdir $ROOTFS_DIR/usr/local/bin -p
  curl -L --retry $max_retries --connect-timeout $timeout -o $ROOTFS_DIR/usr/local/bin/proot "https://github.com/proot-me/proot/releases/download/v${PROOT_VERSION}/proot-v${PROOT_VERSION}-${ARCH}-static"

  while [ ! -s "$ROOTFS_DIR/usr/local/bin/proot" ]; do
    rm $ROOTFS_DIR/usr/local/bin/proot -rf
    curl -L --retry $max_retries --connect-timeout $timeout -o $ROOTFS_DIR/usr/local/bin/proot "https://github.com/proot-me/proot/releases/download/v${PROOT_VERSION}/proot-v${PROOT_VERSION}-${ARCH}-static"

    if [ -s "$ROOTFS_DIR/usr/local/bin/proot" ]; then
      chmod 755 $ROOTFS_DIR/usr/local/bin/proot
      break
    fi

    chmod 755 $ROOTFS_DIR/usr/local/bin/proot
    sleep 1
  done

  chmod 755 $ROOTFS_DIR/usr/local/bin/proot

  printf "nameserver 1.1.1.1\nnameserver 1.0.0.1" > ${ROOTFS_DIR}/etc/resolv.conf
  rm -rf $ROOTFS_DIR/rootfs.tar $ROOTFS_DIR/rootfs.tar.xz $ROOTFS_DIR/sbin
  touch $ROOTFS_DIR/.installed
fi

CYAN='\e[0;36m'
WHITE='\e[0;37m'

RESET_COLOR='\e[0m'

display_gg() {
  echo -e "${WHITE}___________________________________________________${RESET_COLOR}"
  echo -e ""
  echo -e "           ${CYAN}-----> Mission Completed ! <----${RESET_COLOR}"
}

display_gg

$ROOTFS_DIR/usr/local/bin/proot \
  --rootfs="${ROOTFS_DIR}" \
  -0 -w "/root" -b /dev -b /sys -b /proc -b /etc/resolv.conf --kill-on-exit
