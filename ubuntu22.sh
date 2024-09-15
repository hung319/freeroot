#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

ROOTFS_DIR=$(pwd)
export PATH=$PATH:~/.local/usr/bin
MAX_RETRIES=50
TIMEOUT=10
ARCH=$(uname -m)
PROOT_VERSION="5.3.0"

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check and set architecture
if [ "$ARCH" = "x86_64" ]; then
    ARCH_ALT=amd64
elif [ "$ARCH" = "aarch64" ]; then
    ARCH_ALT=arm64
else
    print_message "$RED" "Unsupported CPU architecture: ${ARCH}"
    exit 1
fi

# Check for required commands
for cmd in curl tar; do
    if ! command_exists $cmd; then
        print_message "$RED" "Error: $cmd is not installed. Please install it and try again."
        exit 1
    fi
done

if [ ! -e $ROOTFS_DIR/.installed ]; then
    print_message "$CYAN" "#######################################################################################"
    print_message "$CYAN" "#                                 Foxytoux INSTALLER                                  #"
    print_message "$CYAN" "#                      Copyright (C) 2024, RecodeStudios.Cloud                        #"
    print_message "$CYAN" "#######################################################################################"

    print_message "$GREEN" "Installing Ubuntu 22.04..."

    url="https://fra1lxdmirror01.do.letsbuildthe.cloud/images/ubuntu/jammy/${ARCH_ALT}/default/"
    LATEST_VERSION=$(curl -s $url | grep -oP 'href="\K[^"]+/' | sort -r | head -n 1)
    
    print_message "$YELLOW" "Downloading rootfs..."
    if ! curl -Ls "${url}${LATEST_VERSION}/rootfs.tar.xz" -o "$ROOTFS_DIR/rootfs.tar.xz"; then
        print_message "$RED" "Failed to download rootfs. Please check your internet connection and try again."
        exit 1
    fi

    print_message "$YELLOW" "Extracting rootfs..."
    if ! tar -xf "$ROOTFS_DIR/rootfs.tar.xz" -C "$ROOTFS_DIR"; then
        print_message "$RED" "Failed to extract rootfs. The downloaded file might be corrupted."
        exit 1
    fi

    mkdir -p $ROOTFS_DIR/usr/local/bin

    print_message "$YELLOW" "Downloading proot..."
    proot_url="https://github.com/proot-me/proot/releases/download/v${PROOT_VERSION}/proot-v${PROOT_VERSION}-${ARCH}-static"
    if ! curl -L --retry $MAX_RETRIES --connect-timeout $TIMEOUT -o "$ROOTFS_DIR/usr/local/bin/proot" "$proot_url"; then
        print_message "$RED" "Failed to download proot. Please check your internet connection and try again."
        exit 1
    fi

    chmod 755 $ROOTFS_DIR/usr/local/bin/proot

    print_message "$YELLOW" "Setting up DNS..."
    echo "nameserver 1.1.1.1" > ${ROOTFS_DIR}/etc/resolv.conf
    echo "nameserver 1.0.0.1" >> ${ROOTFS_DIR}/etc/resolv.conf

    print_message "$YELLOW" "Cleaning up..."
    rm -f "$ROOTFS_DIR/rootfs.tar.xz"

    touch $ROOTFS_DIR/.installed
    print_message "$GREEN" "Installation completed successfully!"
else
    print_message "$YELLOW" "Ubuntu 22.04 is already installed. Skipping installation."
fi

print_message "$CYAN" "___________________________________________________"
print_message "$CYAN" ""
print_message "$CYAN" "           -----> Mission Completed! <----"
print_message "$CYAN" ""

print_message "$GREEN" "Starting Ubuntu 22.04..."
exec $ROOTFS_DIR/usr/local/bin/proot \
    --rootfs="${ROOTFS_DIR}" \
    -0 -w "/root" -b /dev -b /sys -b /proc -b /etc/resolv.conf --kill-on-exit
