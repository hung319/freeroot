#!/bin/bash

# Kiểm tra và cài đặt proot nếu chưa có
if ! command -v proot &> /dev/null; then
    echo "proot chưa được cài đặt. Đang cài đặt proot..."
    curl -L https://github.com/proot-me/proot/releases/download/v5.1.0/proot-v5.1.0-x86_64-static -o proot
    chmod +x proot
    sudo mv proot /usr/local/bin/
    echo "Đã cài đặt proot thành công."
else
    echo "proot đã được cài đặt."
fi

# Tạo thư mục cho Ubuntu
mkdir -p ubuntu-fs

# Tải và giải nén rootfs của Ubuntu 22.04
curl -L https://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04-base-amd64.tar.gz | tar -xzC ubuntu-fs

# Thiết lập các file cấu hình cần thiết
echo "nameserver 8.8.8.8" > ubuntu-fs/etc/resolv.conf
echo "ubuntu" > ubuntu-fs/etc/hostname

# Tạo script để chạy Ubuntu
cat > start-ubuntu.sh << EOF
#!/bin/bash
proot -S ubuntu-fs /bin/bash
EOF

chmod +x start-ubuntu.sh

echo "Cài đặt Ubuntu 22.04 hoàn tất. Chạy './start-ubuntu.sh' để bắt đầu phiên Ubuntu."
