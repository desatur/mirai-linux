#  ███▄ ▄███▓ ██▓ ██▀███   ▄▄▄       ██▓
#  ▓██▒▀█▀ ██▒▓██▒▓██ ▒ ██▒▒████▄    ▓██▒
#  ▓██    ▓██░▒██▒▓██ ░▄█ ▒▒██  ▀█▄  ▒██▒
#  ▒██    ▒██ ░██░▒██▀▀█▄  ░██▄▄▄▄██ ░██░
#  ▒██▒   ░██▒░██░░██▓ ▒██▒ ▓█   ▓██▒░██░
#  ░ ▒░   ░  ░░▓  ░ ▒▓ ░▒▓░ ▒▒   ▓▒█░░▓  
#  ░  ░      ░ ▒ ░  ░▒ ░ ▒░  ▒   ▒▒ ░ ▒ ░
#  ░      ░    ▒ ░  ░░   ░   ░   ▒    ▒ ░
#         ░    ░     ░           ░  ░ ░   Build config

#
# IMAGE
#
IMAGE_SIZE=256M
IMAGE_FILENAME=mirai_$(date +%Y%m%d_%H%M%S).img
LOCAL_IMAGE_MOUNTPOINT=/mnt/mirai

#
# BOOTLOADER
#
EFI_PATH=${LOCAL_IMAGE_MOUNTPOINT}/boot/EFI
