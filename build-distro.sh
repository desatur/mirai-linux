#!/bin/sh
set -euo pipefail

# TODO: Improve this script

cat <<'EOF'
 ███▄ ▄███▓ ██▓ ██▀███   ▄▄▄       ██▓
▓██▒▀█▀ ██▒▓██▒▓██ ▒ ██▒▒████▄    ▓██▒
▓██    ▓██░▒██▒▓██ ░▄█ ▒▒██  ▀█▄  ▒██▒
▒██    ▒██ ░██░▒██▀▀█▄  ░██▄▄▄▄██ ░██░
▒██▒   ░██▒░██░░██▓ ▒██▒ ▓█   ▓██▒░██░
░ ▒░   ░  ░░▓  ░ ▒▓ ░▒▓░ ▒▒   ▓▒█░░▓  
░  ░      ░ ▒ ░  ░▒ ░ ▒░  ▒   ▒▒ ░ ▒ ░
░      ░    ▒ ░  ░░   ░   ░   ▒    ▒ ░
       ░    ░     ░           ░  ░ ░   Live Image Builder
EOF

source ./config.sh
mkdir -p builds builds-cache builds-cache/initramfs builds-cache/initramfs/proc builds-cache/initramfs/sys

if mountpoint -q "${LOCAL_IMAGE_MOUNTPOINT}"; then
    echo "Unmounting ${LOCAL_IMAGE_MOUNTPOINT}"
    umount -R "${LOCAL_IMAGE_MOUNTPOINT}"
else
    echo "${LOCAL_IMAGE_MOUNTPOINT} is not mounted"
fi

truncate -s $IMAGE_SIZE "$CACHE_IMAGE_PATH" # Create blank disk image
LOOPDEV=$(losetup --show --find "$CACHE_IMAGE_PATH") # Set up loop device with partitions

# Partition the image
echo -e "o\ny\nn\n1\n\n+64M\nef00\nn\n2\n\n\n8300\nw\ny" | gdisk "$LOOPDEV"
#o  # Create a new GPT partition table
#y  # Confirm the deletion of existing partitions (if any)
#n  # Create a new partition
#1  # Partition number (1 for EFI)
  # First sector (default)
#+64M  # Partition size (64MB for EFI)
#ef00  # Partition type (EFI System)
#n  # Create another partition
#2  # Partition number (2 for root)
#  # First sector (default)
#  # Partition size (remaining space)
#8300  # Partition type (Linux filesystem)
#w  # Write the changes

losetup -d "${LOOPDEV}" # Detach the loop device

LOOPDEV=$(losetup --find --show --partscan "$CACHE_IMAGE_PATH") # Reattach the loop device with partscan

# Format the partitions
mkfs.vfat -F 32 "${LOOPDEV}p1"
mkfs.ext4 "${LOOPDEV}p2"

# Mount rootfs
mount "${LOOPDEV}p2" "$LOCAL_IMAGE_MOUNTPOINT"

# Now create the boot/EFI mount point *inside* the mounted root
mkdir -p "$EFI_PATH"

# Mount the EFI System Partition
mount "${LOOPDEV}p1" "$EFI_PATH"

# Clone Linux repo if it doesn't already exist
if [ ! -d linux ]; then
    git clone --depth 1 https://github.com/torvalds/linux.git
fi

# Clone Busybox repo if it doesn't already exist
if [ ! -d busybox ]; then
    git clone --depth 1 https://git.busybox.net/busybox.git
fi

cp "./linux-config/.config" "./linux/.config"
cp "./busybox-config/.config" "./busybox/.config"

# Build the kernel
cd linux
make -j"$(nproc)"
cd ..

# Copy built kernel image
BZIMAGE_SOURCE="linux/arch/x86/boot/bzImage"
BZIMAGE_TARGET="builds-cache/bzImage"
if [ -f "$BZIMAGE_SOURCE" ]; then
    cp "$BZIMAGE_SOURCE" "$BZIMAGE_TARGET"
else
    echo "Kernel image not found: $BZIMAGE_SOURCE"
    exit 1
fi

# Build busybox into the initramfs
cd busybox
make -j"$(nproc)"
make CONFIG_PREFIX=../builds-cache/initramfs install
cd ..

# Copy init script into initramfs
cp "./initscript/init" "./builds-cache/initramfs/init"
chmod +x ./builds-cache/initramfs/init

# Not needed
rm ./builds-cache/initramfs/linuxrc

# Pack initramfs into init.cpio
(cd ./builds-cache/initramfs/ && find . -print0 | cpio --null -ov --format=newc) > ./builds-cache/init.cpio

# Install GRUB
grub-install \
  --target=x86_64-efi \
  --efi-directory="$EFI_PATH" \
  --boot-directory="$LOCAL_IMAGE_MOUNTPOINT/boot" \
  --bootloader-id=GRUB \
  --removable \
  --recheck

mkdir -p $LOCAL_IMAGE_MOUNTPOINT/boot/grub/x86_64-efi/
cp -r /usr/lib/grub/x86_64-efi/*.mod "$LOCAL_IMAGE_MOUNTPOINT/boot/grub/x86_64-efi/"

ROOT_UUID=$(blkid -s UUID -o value "${LOOPDEV}p2")
echo "Root partition UUID is $ROOT_UUID"

# Copy the GRUB config
mkdir -p "$LOCAL_IMAGE_MOUNTPOINT/boot/grub"
cp "./grub-config/live.cfg" "$LOCAL_IMAGE_MOUNTPOINT/boot/grub/grub.cfg"

cp ./builds-cache/bzImage ${LOCAL_IMAGE_MOUNTPOINT}/boot/vmlinuz
cp ./builds-cache/init.cpio ${LOCAL_IMAGE_MOUNTPOINT}/boot/initrd.img

umount -R "${LOCAL_IMAGE_MOUNTPOINT}"
losetup -d "$LOOPDEV"

echo "Copying and renaming into ./builds"
cp "./builds-cache/boot.img" "./builds/mirai_$(date +%Y%m%d_%H%M%S).img"
echo "Done"