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

CYAN='\e[0;36m'
WHITE='\e[0;37m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

RESET_COLOR='\e[0m'

if [ ! -e $ROOTFS_DIR/.installed ]; then
  echo "${GREEN}╭────────────────────────────────────────────────────────────────────────────────╮${NC}"
  echo "${GREEN}│                                                                                │${NC}"
  echo "${GREEN}│                             Ubuntu 22.04 Installer                             │${NC}"
  echo "${GREEN}│                                                                                │${NC}"
  echo "${GREEN}╰────────────────────────────────────────────────────────────────────────────────╯${NC}"

  read -p "Do you want to install Ubuntu 22.04? (y/n): " install_ubuntu
fi

case $install_ubuntu in
  [yY])
    echo "${GREEN}Installing Ubuntu 22.04 LTS (jammy)...${NC}"
    url="https://fra1lxdmirror01.do.letsbuildthe.cloud/images/ubuntu/jammy/${ARCH_ALT}/default/"
    LATEST_VERSION=$(curl -s $url | grep -oP 'href="\K[^"]+/' | sort -r | head -n 1)

    curl -L --retry $max_retries --connect-timeout $timeout -o $ROOTFS_DIR/rootfs.tar.xz "${url}${LATEST_VERSION}/rootfs.tar.xz"
    tar -xf $ROOTFS_DIR/rootfs.tar.xz -C "$ROOTFS_DIR"
    mkdir $ROOTFS_DIR/home/container/ -p
    ;;
  *)
    echo "Skipping Ubuntu installation."
    exit 1
    ;;
esac

if [ ! -e $ROOTFS_DIR/.installed ]; then
  mkdir $ROOTFS_DIR/usr/local/bin -p
  curl -L --retry $max_retries --connect-timeout $timeout -o $ROOTFS_DIR/usr/local/bin/proot "https://github.com/proot-me/proot/releases/download/v5.3.0/proot-v5.3.0-${ARCH}-static"

  while [ ! -s "$ROOTFS_DIR/usr/local/bin/proot" ]; do
    rm $ROOTFS_DIR/usr/local/bin/proot -rf
    curl -L --retry $max_retries --connect-timeout $timeout -o $ROOTFS_DIR/usr/local/bin/proot "https://github.com/proot-me/proot/releases/download/v5.3.0/proot-v5.3.0-${ARCH}-static"

    if [ -s "$ROOTFS_DIR/usr/local/bin/proot" ]; then
      chmod 755 $ROOTFS_DIR/usr/local/bin/proot
      break
    fi

    sleep 1
  done

  chmod 755 $ROOTFS_DIR/usr/local/bin/proot
fi

if [ ! -e $ROOTFS_DIR/.installed ]; then
  printf "nameserver 1.1.1.1\nnameserver 1.0.0.1" > ${ROOTFS_DIR}/etc/resolv.conf
  rm -rf $ROOTFS_DIR/rootfs.tar.xz /tmp/sbin
  touch $ROOTFS_DIR/.installed
fi

display_complete() {
  echo -e "${WHITE}___________________________________________________${RESET_COLOR}"
  echo -e ""
  echo -e "           ${CYAN}-----> Installation Completed! <----${RESET_COLOR}"
}

clear
display_complete

# Get all ports from vps.config
port_args=""
if [ -f "$ROOTFS_DIR/vps.config" ]; then
  while read line; do
    case "$line" in
      internalip=*) ;;
      port[0-9]*=*) port=${line#*=}; if [ -n "$port" ]; then port_args=" -p $port:$port$port_args"; fi;;
      port=*) port=${line#*=}; if [ -n "$port" ]; then port_args=" -p $port:$port$port_args"; fi;;   
    esac
  done < "$ROOTFS_DIR/vps.config"
fi

$ROOTFS_DIR/usr/local/bin/proot \
  --rootfs="${ROOTFS_DIR}" \
  -0 -w "/root" -b /dev -b /sys -b /proc -b /etc/resolv.conf $port_args --kill-on-exit \
  /bin/bash
