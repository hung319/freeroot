#!/bin/sh

ROOTFS_DIR=$(pwd)
PROOT_VERSION="5.3.0"

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH_PD="x86_64"
elif [ "$ARCH" = "aarch64" ]; then
    ARCH_PD="aarch64"
elif [ "$ARCH" = "armv7l" ]; then
    ARCH_PD="armv7"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

OS_VERSION="3.22"
OS_FULL="3.22.1"
IMAGE_URL="https://github.com/alpinelinux/docker-alpine/raw/refs/heads/v${OS_VERSION}/${ARCH_PD}/alpine-minirootfs-${OS_FULL}-${ARCH_PD}.tar.gz"

mkdir -p tmp
if [ -e "$ROOTFS_DIR/.installed" ]; then
    echo "OS đã được cài rồi, skip bước cài đặt"
else
    echo "[*] Đang tải rootfs..."
    curl -Lo ./tmp/rootfs.tar.xz "$IMAGE_URL"

    mkdir -p "$ROOTFS_DIR"
    tar -xvf ./tmp/rootfs.tar.xz -C "$ROOTFS_DIR"

    mkdir -p $ROOTFS_DIR/usr/local/bin
    echo "[*] Đang tải proot..."
    curl -Lo "$ROOTFS_DIR/usr/local/bin/proot" \
        "https://github.com/proot-me/proot/releases/download/v${PROOT_VERSION}/proot-v${PROOT_VERSION}-${ARCH}-static"
    chmod 755 "$ROOTFS_DIR/usr/local/bin/proot"

    echo "[*] Set DNS"
    echo "nameserver 1.1.1.1" > "$ROOTFS_DIR/etc/resolv.conf"
    echo "nameserver 1.0.0.1" >> "$ROOTFS_DIR/etc/resolv.conf"

    echo "[*] Cleanup..."
    rm -f ./tmp/rootfs.tar.xz

    touch "$ROOTFS_DIR/.installed"
fi

clear && cat << "EOF"
██████╗ ███████╗██████╗ ██╗███████╗ █████╗ ███╗   ██╗
██╔══██╗██╔════╝██╔══██╗██║██╔════╝██╔══██╗████╗  ██║
██║  ██║█████╗  ██████╔╝██║███████╗███████║██╔██╗ ██║
██║  ██║██╔══╝  ██╔══██╗██║╚════██║██╔══██║██║╚██╗██║
██████╔╝███████╗██║  ██║██║███████║██║  ██║██║ ╚████║
╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝
Welcome to Alpine rootfs!
EOF

"$ROOTFS_DIR/usr/local/bin/proot" \
    --rootfs="$ROOTFS_DIR" \
    --link2symlink \
    --kill-on-exit \
    --root-id \
    --cwd=/root \
    --bind=/proc \
    --bind=/dev \
    --bind=/sys \
    --bind=/tmp \
    /bin/sh
