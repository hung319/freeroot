#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Color definitions
PURPLE='\033[0;35m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'  # No Color

# Define the root directory
ROOTFS_DIR=/home/container
export PATH=$PATH:~/.local/usr/bin

PROOT_VERSION="5.3.0"

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

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH_ALT=amd64
elif [ "$ARCH" = "aarch64" ]; then
    ARCH_ALT=arm64
else
    print_message "$RED" "Unsupported CPU architecture: ${ARCH}"
    exit 1
fi

# Function to download and extract rootfs
download_and_extract() {
    local url=$1
    local version=$2
    
    print_message "$YELLOW" "Downloading rootfs..."
    if ! curl -Ls "${url}${version}/rootfs.tar.xz" -o "$ROOTFS_DIR/rootfs.tar.xz"; then
        print_message "$RED" "Failed to download rootfs. Please check your internet connection and try again."
        exit 1
    fi

    print_message "$YELLOW" "Extracting rootfs..."
    if command_exists xz; then
        if ! tar -xf "$ROOTFS_DIR/rootfs.tar.xz" -C "$ROOTFS_DIR"; then
            print_message "$RED" "Failed to extract rootfs. The downloaded file might be corrupted."
            exit 1
        fi
    else
        print_message "$YELLOW" "xz command not found. Attempting alternative extraction method..."
        if command_exists unxz; then
            unxz "$ROOTFS_DIR/rootfs.tar.xz"
            if ! tar -xf "$ROOTFS_DIR/rootfs.tar" -C "$ROOTFS_DIR"; then
                print_message "$RED" "Failed to extract rootfs. The downloaded file might be corrupted."
                exit 1
            fi
            rm "$ROOTFS_DIR/rootfs.tar"
        else
            print_message "$RED" "Neither xz nor unxz commands are available. Cannot extract rootfs."
            print_message "$YELLOW" "Please install xz-utils package and try again."
            exit 1
        fi
    fi

    mkdir -p $ROOTFS_DIR/home/container/
}

# Function to display the menu and get user selection
display_menu() {
    print_message "$GREEN" "╭────────────────────────────────────────────────────────────────────────────────╮"
    print_message "$GREEN" "│                             LylaNodes VM - EGG                                │"
    print_message "$GREEN" "│                           © 2021 - 2024 vizle                                 │"
    print_message "$GREEN" "╰────────────────────────────────────────────────────────────────────────────────╯"
    print_message "$YELLOW" "Please choose your favorite distro:"
    
    local options=("Debian" "Ubuntu" "Void Linux" "Alpine Linux (Edge)" "CentOS" "Rocky Linux" "Fedora" "AlmaLinux" "Slackware Linux" "Kali Linux" "openSUSE" "Gentoo Linux" "Arch Linux" "Devuan Linux")
    
    for i in "${!options[@]}"; do
        echo "* [$(($i+1))] ${options[$i]}"
    done

    print_message "$YELLOW" "Enter OS (1-${#options[@]}):"
    read -p "" input
    echo $input
}

# Function to handle Debian installation
install_debian() {
    local versions=("Debian 12 (bookworm)" "Debian 11 (bullseye)" "Debian 10 (buster)" "Debian 13 (trixie) (unstable)" "Debian (sid) (unstable)")
    local urls=("bookworm" "bullseye" "buster" "trixie" "sid")
    
    print_message "$YELLOW" "Choose Debian version:"
    for i in "${!versions[@]}"; do
        echo "* [$(($i+1))] ${versions[$i]}"
    done
    
    read -p "Enter the desired version (1-${#versions[@]}): " version
    if [ "$version" -ge 1 ] && [ "$version" -le "${#versions[@]}" ]; then
        local index=$((version-1))
        print_message "$GREEN" "Installing ${versions[$index]}..."
        url="https://fra1lxdmirror01.do.letsbuildthe.cloud/images/debian/${urls[$index]}/${ARCH_ALT}/default/"
        LATEST_VERSION=$(curl -s $url | grep -oP 'href="\K[^"]+/' | sort -r | head -n 1)
        download_and_extract $url $LATEST_VERSION
    else
        print_message "$RED" "Invalid selection. Exiting."
        exit 1
    fi
}

# Main installation logic
if [ ! -e "$ROOTFS_DIR/.installed" ]; then
    print_message "$PURPLE" "Welcome to the Linux Installer!"
    
    selection=$(display_menu)
    
    case $selection in
        1) install_debian ;;
        2) 
            print_message "$GREEN" "Installing Ubuntu..."
            # Add Ubuntu installation logic here
        ;;
        3) 
            print_message "$GREEN" "Installing Void Linux..."
            url="https://fra1lxdmirror01.do.letsbuildthe.cloud/images/voidlinux/current/${ARCH_ALT}/default/"
            LATEST_VERSION=$(curl -s $url | grep -oP 'href="\K[^"]+/' | sort -r | head -n 1)
            download_and_extract $url $LATEST_VERSION
        ;;
        # Add cases for other distributions...
        *)
            print_message "$RED" "Invalid selection. Exiting."
            exit 1
        ;;
    esac

    # Download run.sh
    curl -Ls "https://raw.githubusercontent.com/vekalmao/lylanodes-vps-egg/main/run.sh" -o "$ROOTFS_DIR/home/container/run.sh"
    chmod +x "$ROOTFS_DIR/home/container/run.sh"

    # Download static proot
    mkdir -p "$ROOTFS_DIR/usr/local/bin"
    curl -Ls "https://github.com/proot-me/proot/releases/download/v${PROOT_VERSION}/proot-v${PROOT_VERSION}-${ARCH}-static" -o "$ROOTFS_DIR/usr/local/bin/proot"
    chmod 755 "$ROOTFS_DIR/usr/local/bin/proot"

    # Setup DNS
    printf "nameserver 1.1.1.1\nnameserver 1.0.0.1" > "${ROOTFS_DIR}/etc/resolv.conf"

    # Cleanup
    rm -rf $ROOTFS_DIR/rootfs.tar.xz /tmp/sbin
    touch "$ROOTFS_DIR/.installed"

    print_message "$GREEN" "Installation completed successfully!"
else
    print_message "$YELLOW" "Linux system is already installed. Skipping installation."
fi

# Start PRoot environment
print_message "$GREEN" "Starting Linux environment..."

# Get all ports from vps.config
port_args=""
while read line; do
    case "$line" in
        internalip=*) ;;
        port[0-9]*=*) port=${line#*=}; if [ -n "$port" ]; then port_args+=" -p $port:$port"; fi;;
        port=*) port=${line#*=}; if [ -n "$port" ]; then port_args+=" -p $port:$port"; fi;;   
    esac
done < "$ROOTFS_DIR/vps.config"

# Start PRoot
"$ROOTFS_DIR/usr/local/bin/proot" \
    --rootfs="${ROOTFS_DIR}" \
    -0 -w "/root" -b /dev -b /sys -b /proc -b /etc/resolv.conf $port_args --kill-on-exit \
    /bin/sh "$ROOTFS_DIR/run.sh"
