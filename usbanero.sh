#!/usr/bin/env bash

# Add an external hard drive to your Raspberry Pi

# This script will configure a Raspbian system to use an external USB drive as a
# root filesystem; boot the system from the hard drive, avoiding limited write
# cycles to your microSD card


################################################################################
# Display a message to the user - useful for prompts or info
# Use:
#     msg "subject" "message line here"
function msg() {
   msg="$1"
   shift
   CL1="1;32m"   # Bold; Green
   CL2="1;35m"   # Bold; Magenta
   BG="40m"      # Black background
   echo -en "\033[${CL1}\033[${BG} ${msg} \033[0m "
   echo -e  "\033[${CL2}\033[${BG} $* \033[0m"
}
################################################################################


################################################################################
# Display version info
function print_version() {
   echo
   echo "Homeslice External HDD Installer v16.04.a"
   echo
   exit 1
}
################################################################################


################################################################################
function print_help() {
   echo
   echo "Usage: sudo $0 -d [device]"
   echo "   -h            Print help"
   echo "   -v            Print version information"
   echo "   -d [device]   Specify path of device to convert"
   echo
   echo "You must specify a target device."
   echo
   exit 1
}
################################################################################


################################################################################
# Display an error message and quit
# Use:
#     abort "error message here"
function abort() {
   CL1="1;91m"   # Bold; Red
   CL2="1;93m"   # Bold; Yellow
   BG="40m"      # Black background
   echo
   echo -en "\033[${CL1}\033[${BG} [ERROR] \033[0m "
   echo -en "\033[${CL2}\033[${BG} $* \033[0m"
   echo
   exit 1
}
################################################################################


################################################################################
# Root user permissions check
if [[ $EUID -ne 0 ]]; then
    abort "You do not have root permissions.  Try: sudo $0"
fi
################################################################################


################################################################################
# args:
#      -h -v -d
args=$(getopt -uo 'hvd:' -- $*)
[ $? != 0 ] && print_help
set -- $args

for i
do
   case "$i"
   in
      -h)
         print_help
         ;;
      -v)
         print_version
         ;;
      -d)
         target_device="$2"
         msg "DEVICE = " "${2}"
         shift
         shift
         ;;
   esac
done

if [[ ! -e "$target_device" ]]; then
    abort "Device ${target_device} must be existing target (most likely -d /dev/sda)"
fi
################################################################################


msg
msg "INIT" "This will add an external hard drive to your Raspbery Pi, configure"
msg "INIT" "it to boot from the HDD, and enable a larger swap partition."
msg
msg "INIT" "WARNING: THIS WILL FORMAT AND PARTITION YOUR CONNECTED HARD DRIVE"
msg "INIT" "ALL DATA WILL BE LOST on ${target_device}"

# Checks whether or not user is sure they want to continue
read -p "Are you sure you want to continue? (y/n)" -n 1 -r
echo # new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    msg "QUIT" "That is OK, Homeslice.  Perhaps another time..."
    exit 1
fi

export partition1="${target_device}1"
export partition2="${target_device}2"

msg "PACKAGES" "Installing the necessary packages"
   apt-get install ntfs-3g ntfs-config gdisk rsync parted -y

msg "DEVICE" "Partitioning your HDD"
   parted --script "${target_device}" \
      mklabel gpt \
      mkpart primary ext4 0GB 16GB \
      mkpart primary ntfs 16GB 100%

msg "DEVICE" "Formatting your HOMESLICE partition."
   mkfs -t ext4 -L rootfs "${partition1}"
   mkfs.ntfs -Q -L HOMESLICE "${partition2}"


msg "DEVICE" "Copying microSD to hard drive."
msg "DEVICE" "Chill, Homeslice... this can take awhile."
   # (dd bs=32M if=/dev/mmcblk0p2 conv=noerror,sync) | pv | (dd of="${partition1}")
   mount "${partition1}" /mnt
   rsync -axvh / /mnt

# msg "DEVICE" "Checking hard drive for errors."
   # e2fsck -f "${partition1}" -y

# msg "DEVICE" "Expanding your hard drive."
   # resize2fs "${partition1}"

msg "BOOT" "Gathering your Partition unique GUID"
   uuid1="$(blkid -s UUID -o value ${partition1})"
   uuid2="$(blkid -s UUID -o value ${partition2})"
   puuid1="$(blkid -s PARTUUID -o value ${partition1})"
msg "BOOT" "Your 1st Partition UUID is: ${uuid1}"
msg "BOOT" "Your 1st Partition unique GUID is: ${puuid1}"
msg "BOOT" "Your 2nd Partition UUID is: ${uuid2}"

msg "BOOT" "Making a backup of the bootloader..."
msg "BOOT" "Just in case, Homeslice."
   cp /boot/cmdline.txt /boot/cmdline.txt.bak

msg "BOOT" "Changing the bootloader to look for your hard drive"
   # Tell the bootloader to look for the unique partition UUID of HDD
   sed -i "s|root=\/dev\/mmcblk0p2|root=PARTUUID=${puuid1}|" /boot/cmdline.txt
   # Append rootdelay=5 to the bootloader
   sed -i '1 s/$/ rootdelay=5/' /boot/cmdline.txt
   # End result (use cat /boot/cmdline.txt):
   #              dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1
   #              root=PARTUUID=f0e5151b-b888-4c06-85c7-13a1c583daf6
   #              rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait
   #              rootdelay=5

msg "BOOT" "Making changes to /etc/fstab"
   sed -i '/mmcblk0p2/s/^/#/' /mnt/etc/fstab
   echo "/dev/disk/by-uuid/${uuid1}    /   ext4    defaults,noatime  0       1" >> /mnt/etc/fstab
   echo "/dev/disk/by-uuid/${uuid2}    /mnt/homeslice    ntfs    defaults     0     0" >> /mnt/etc/fstab

msg "BOOT" "Creating data directory /mnt/homeslice (all files live here)"
   mkdir /mnt/homeslice

msg "CONFIG" "Complete."
msg "CONFIG" "/etc/fstab"
   cat /etc/fstab
msg "CONFIG" "/boot/cmdline.txt"
   cat /boot/cmdline.txt

msg "CONFIG" "Drive succesfully installed and accessible under /mnt"
msg "CONFIG" "You MUST reboot the device in order to mount at /"

msg "EXIT" "Reboot your Raspberry Pi now.  Try:"
msg "EXIT" "                                    sudo reboot"
