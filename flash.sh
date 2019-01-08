#!/bin/sh

# TODO: Check if FUSE mounted and unmount

# Mountpont to mount Flash drive. Will be creted if does not exist
DEV_MOUNT="/mnt/flash_copy"
# Foulder with files to write on Flash
SRC_FOLDER="flash_copy"
# Vendor and Device IDs of the flash stick
DEV_ID="0x058f:0x6387"

if [ ! -d $SRC_FOLDER ]; then
  echo "Cannot find source directory!"
  exit 1
fi

while : ; do
  # Step 1: Detect USB Flash stick
  DEV_SERIAL=""
  echo "Please insert USB Flash"
  while [ -z $DEV_SERIAL ] ; do
    DEV_SERIAL=$(sudo lsusb -d $DEV_ID -v | grep iSerial | awk '{ print $3 }')
    sleep 1
  done
  udevadm settle
  echo "Found device $DEV_SERIAL"

  # Step 2: Wipe device & create single clean partition and FAT32 filesystem
  DEV_PART=$(readlink -e /dev/disk/by-id/usb-Generic_Flash_Disk_$DEV_SERIAL-0\:0)
  if [ -z $DEV_PART ]; then
    echo "Cannot find USB device"
    exit 1
  fi
  sudo wipefs -a -f -q $DEV_PART
  echo 'start=2048, type=b' | sudo sfdisk -q -X dos $DEV_PART
  DEV_PART=$DEV_PART'1'
  sudo mkfs.vfat $DEV_PART

  # Step 3: Mount detected drive & copy files
  if [ ! -d $DEV_MOUNT ]; then
    sudo mkdir $DEV_MOUNT
  fi
  sudo mount $DEV_PART $DEV_MOUNT
  DEV_SIZE=$(df -B1 $DEV_MOUNT | grep -vE '^Filesystem' | awk '{ print $4 }')
  SRC_SIZE=$(du -b $SRC_FOLDER | awk '{ print $1 }')
  if [ $SRC_SIZE \> $DEV_SIZE ]; then
    echo "USB Flash is too small"
  else
    sudo cp $SRC_FOLDER/* $DEV_MOUNT
    echo "Copying contents of $SRC_FOLDER to USB Flash $DEV_SERIAL"
  fi
  sudo umount $DEV_MOUNT

  # Step 3: Finish
  echo "Please remove USB Flash to continue"
  while sudo lsusb -d $DEV_ID -v | grep -q $DEV_SERIAL; do
    sleep 1
  done
done
