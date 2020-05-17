#!/bin/bash
# A simple script to make your own Devuan pi4 arm64 sdcard
# Using the foundation's kernel and stuff @
# http://archive.raspberrypi.org/debian/pool/main/r/raspberrypi-firmware
#
# Beerware By ShorTie	<idiot@dot.com> 

# Turn off path caching.
set +h

hostname=Devuan
root_password=rtyu 	# Define your own root password here

#ARCH=arm
ARCH=arm64

#release=ascii
release=beowulf
#release=ceres

timezone=America/New_York 	# You can define this here or remark out or leave blank to use current systems
locales=en_US.UTF-8			# You can define this here or remark out or leave blank to use current systems
default_locale=en_US.UTF-8	# You can define this here or remark out or leave blank to use current systems

number_of_keys=104		# You can define this here or remark out or leave blank to use current systems
keyboard_layout=us		# must be defined if number_of_keys is defined
keyboard_variant=		# blank is normal
keyboard_options=		# blank is normal
backspace=guess			# guess is normal

#************************************************************************

# Define message colors
OOPS="\033[1;31m"    # red
DONE="\033[1;32m"    # green
INFO="\033[1;33m"    # yellow
STEP="\033[1;34m"    # blue
WARN="\033[1;35m"    # hot pink
BOUL="\033[1;36m"	 # light blue
NO="\033[0m"         # normal/light

# Check to see if Devuan-pi4_os64.sh is being run as root
start_time=$(date)
echo -e "${STEP}\n  Checking for root .. ${NO}"
if [ `id -u` != 0 ]; then
    echo "nop"
    echo -e "Ooops, Devuan-pi4_os64.sh needs to be run as root !!\n"
    echo " Try 'sudo sh, ./Devuan-pi4_os64.sh' as a user"
    exit
else
    echo -e "${INFO}  Yuppers,${BOUL} root it tis ..${DONE} :)~${NO}"
fi

if [ ! -d debs ]; then
  echo -e "${STEP}\n  Making debs directory ${NO}"
  mkdir -v debs
fi

if [ ! -e debs/Dependencies-ok ]; then
  echo -e "${STEP}\n  Installing dependencies ..  ${NO}"
    apt install dosfstools inotify-tools parted xz-utils
  touch debs/Dependencies-ok
fi


fail () {
    echo -e "${WARN}\n\n  Oh no's,${INFO} Sumfin went wrong\n ${NO}"
    echo -e "${STEP}  Cleaning up my mess .. ${OOPS}:(~ ${NO}"
    umount -v sdcard/proc
    umount -v sdcard/sys
    umount -v sdcard/dev/pts
    umount -v sdcard/boot
    umount -v sdcard
    rm -rvf sdcard
    exit
}

echo -e "${STEP}  Setting Trap ${NO}"
trap "echo; echo \"Unmounting /proc\"; fail" SIGINT SIGTERM

    echo -e "${OOPS}\n\n  Oh no's,${WARN} Sumfin went wrong\n ${NO}"
    echo -e "${STEP}  Cleaning up my mess .. ${OOPS}:(~ ${NO}"
    umount -v sdcard/proc
    umount -v sdcard/sys
    umount -v sdcard/dev/pts
    umount -v sdcard/boot
    umount -v sdcard
    rm -rvf sdcard

echo
echo -e "${DONE}  Just kidding,${WARN} lol. ${NO}"
echo -e "${STEP}  Just making sure of a kleen enviroment .. ${BOUL}:/~ ${NO}"
echo
echo -e "${DONE}  Plug in flash drive ${NO}"

# Wait until a new [0-9] node appears in /dev
#   This should be OK because there should be few device changes during operation
DEV_FILE="/tmp/inotify_devs"
INOTIFY_CMD="inotifywait -q"
WATCH="CREATE"

# Watch for CREATEs in /dev of xxx[0-9]*
$INOTIFY_CMD -m --exclude "t[my]" /dev | while read a b c; do
  if [ "$b" != "$WATCH" ]; then continue; fi
  C="${c/[0-9]*/}"
  if [ "$c" != "$C" -a -e "$a$C" -a -e "$a${C}1" ]; then
    echo "${C}" > ${DEV_FILE}
    exit  # This exits the 'while read' subprocess
  fi
done
read fldev <$DEV_FILE
rm -f $DEV_FILE

# Pause for reflection
echo -e "${STEP}  Pause for reflection ${NO}"
sleep 2
echo; echo -e "${STEP}  Flash drive is /dev/${DONE}${fldev} ${NO}"; echo

echo -e "${STEP}  Zero out the beginning of the SD card: ${NO}"
dd if=/dev/zero of=/dev/${fldev} bs=1M count=420

# Create partitions
echo -e "${STEP}\n\n  Creating partitions ${NO}"
fdisk /dev/${fldev} <<EOF
o
n
p
1

+256M
a
t
6
n
p
2


w
EOF

echo -e "${STEP}\n  Partprobing /dev/${DONE}${fldev} ${NO}"
partprobe /dev/${fldev}
fdisk -l /dev/${fldev}

# Format partitions
echo -e "${STEP}\n\n  Formating partitions ${NO}"
echo "mkfs.fat -n boot /dev/${fldev}1"
mkfs.fat -n boot /dev/${fldev}1
echo
echo "mkfs.ext4 -O ^huge_file  -L Debian64 /dev/${fldev}2"; echo
mkfs.ext4 -O ^huge_file  -L Debian64 /dev/${fldev}2 && sync
echo

echo -e "${STEP}\n  Setting up for debootstrap ${NO}"
mkdir -v sdcard
mount -v -t ext4 -o sync /dev/${fldev}2 sdcard

echo -e "${STEP}\n  Copying debs ${NO}"
mkdir -vp sdcard/var/cache/apt/archives
cp debs/*.deb sdcard/var/cache/apt/archives

if [ ! -d debs/debootstrap ]; then
    wget -nc -P debs http://deb.devuan.org/devuan/pool/main/d/debootstrap/debootstrap_1.0.123+devuan1.tar.gz
    mkdir -vp debs/debootstrap
    tar xf debs/debootstrap_1.0.123+devuan1.tar.gz -C debs/debootstrap
fi

# These are added to debootstrap now so no setup Dialog boxes are done, configuration done later.
include="--include=kbd,locales,keyboard-configuration,console-setup,dphys-swapfile,devuan-keyring"

echo -e "${STEP}\n  debootstrap's line is ${NO}"
debootstrapline=" --arch ${ARCH} ${include} ${release} sdcard"
echo ${debootstrapline}; echo
DEBOOTSTRAP_DIR=debs/debootstrap/source debs/debootstrap/source/debootstrap --arch ${ARCH} ${include} ${release} sdcard || fail

echo -e "${STEP}\n  Mount new chroot system\n ${NO}"
mount -v -t vfat -o sync /dev/${fldev}1 sdcard/boot
mount -v proc sdcard/proc -t proc
mount -v sysfs sdcard/sys -t sysfs
mount -v --bind /dev/pts sdcard/dev/pts

# Adjust a few things
echo -e "${INFO}\n\n  Copy, adjust and reconfigure ${NO}"

echo -e "${STEP}\n  Adjusting /etc/apt/sources.list from/too... ${NO}"
cat sdcard/etc/apt/sources.list
  sed -i sdcard/etc/apt/sources.list -e "s/main/main contrib non-free/"
#  echo "deb http://deb.devuan.org/merged ${release} main contrib non-free" >> sdcard/etc/apt/sources.list
#echo "deb http://deb.devuan.org/merged ${release} main contrib non-free" > sdcard/etc/apt/sources.list
cat sdcard/etc/apt/sources.list

echo -e "${STEP}\n  Setting up the root password... ${NO} $root_password "
echo root:$root_password | chroot sdcard chpasswd

echo -en "${STEP}  Changing timezone too...  ${NO}"
if [ "${timezone}" == "" ]; then 
    cp -v /etc/timezone sdcard/etc/timezone
else
    echo ${timezone} > sdcard/etc/timezone
fi
cat sdcard/etc/timezone

echo -en "${STEP}\n  Adjusting locales too...  ${NO}"
if [ "$locales" == "" ]; then 
    cp -v /etc/locale.gen sdcard/etc/locale.gen
else
    sed -i "s/^# \($locales .*\)/\1/" sdcard/etc/locale.gen
fi
grep -v '^#' sdcard/etc/locale.gen

echo -en "${STEP}\n  Adjusting default local too...  ${NO}"
if [ "$default_locale" == "" ]; then 
    default_locale=$(fgrep "=" /etc/default/locale | cut -f 2 -d '=')
fi
echo $default_locale

echo -e "${STEP}\n  Setting up keyboard ${NO}"
if [ "$number_of_keys" == "" ]; then 
    cp -v /etc/default/keyboard sdcard/etc/default/keyboard
else
    # adjust variables
    xkbmodel=XKBMODEL='"'$number_of_keys'"'
    xkblayout=XKBLAYOUT='"'$keyboard_layout'"'
    xkbvariant=XKBVARIANT='"'$keyboard_variant'"'
    xkboptions=XKBOPTIONS='"'$keyboard_options'"'
    backspace=BACKSPACE='"'$backspace'"'

    # make keyboard file
    cat <<EOF > sdcard/etc/default/keyboard
# KEYBOARD CONFIGURATION FILE

$xkbmodel
$xkblayout
$xkbvariant
$xkboptions

$backspace

EOF
fi
cat sdcard/etc/default/keyboard
# end keyboard

echo -e "${STEP}\n  Setting dphys-swapfile size to 100meg ${NO}"
echo "CONF_SWAPSIZE=100" > sdcard/etc/dphys-swapfile

echo -e "${STEP}  Creating fstab ${NO}"
cat <<EOF > sdcard/etc/fstab
#<file system>  <dir>          <type>   <options>       <dump>  <pass>
proc            /proc           proc    defaults          0       0
/dev/mmcblk0p1  /boot           vfat    defaults          0       2
/dev/mmcblk0p2  /               ext4    defaults,noatime  0       1
# a swapfile is not a swap partition, so no using swapon|off from here on, use  dphys-swapfile swap[on|off]  for that
EOF

cat sdcard/etc/fstab && sync; echo

echo -e "${STEP}\n  local-gen  LANG=${default_locale} ${NO}"
chroot sdcard locale-gen LANG="$default_locale"

echo -e "${STEP}\n  dpkg-reconfigure -f noninteractive locales ${NO}"
chroot sdcard dpkg-reconfigure -f noninteractive locales

echo -e "${STEP}\n  dpkg-reconfigure -f noninteractive tzdata ${NO}"
chroot sdcard dpkg-reconfigure -f noninteractive tzdata

echo -e "${STEP}\n  dpkg-reconfigure -f noninteractive keyboard-configuration ${NO}"
chroot sdcard dpkg-reconfigure -f noninteractive keyboard-configuration

echo -e "${STEP}\n  dpkg-reconfigure -f noninteractive console-setup ${NO}"
chroot sdcard dpkg-reconfigure -f noninteractive console-setup

echo -e "${STEP}\n  Prevent the console from clearing the screen ${NO}"
mkdir -vp sdcard/etc/systemd/system/getty@.service.d
cat >sdcard/etc/systemd/system/getty@.service.d/noclear.conf <<EOF
[Service]
TTYVTDisallocate=no
EOF


echo -e "${DONE}\n  Done Coping, adjusting and reconfiguring ${NO}"


# net-tweaks
echo -e "${STEP}\n  Setting up networking ${NO}"

echo $hostname > sdcard/etc/hostname
install -v -m 0644 /etc/resolv.conf sdcard/etc/resolv.conf

cat <<EOF > sdcard/etc/hosts
127.0.0.1	localhost
::1		localhost ip6-localhost ip6-loopback
ff02::1		ip6-allnodes
ff02::2		ip6-allrouters

127.0.1.1	${hostname}

EOF

echo -e "${STEP}\n  hostname ${NO}"; cat sdcard/etc/hostname
echo -e "${STEP}\n  resolv.conf ${NO}"; cat sdcard/etc/resolv.conf
echo -e "${STEP}\n  hosts ${NO}"; cat sdcard/etc/hosts

# end Networking


# openssh-client
EXTRAS="dhcpcd5 ntp mlocate ssh wpasupplicant"
echo -e "${STEP}\n  Install ${DONE}${EXTRAS}\n ${NO}"
#chroot sdcard apt update || fail
chroot sdcard apt-get install -y ${EXTRAS} || fail

#	###########  Done with basic system  ################

echo -e "${STEP}  apt-get install -y  debhelper  ...  ${NO}"
#chroot sdcard apt-get install -y  debhelper bc bison flex gcc-8 libssl-dev libkmod-dev kmod perl



#	###########  Install kernel  ##########

echo -e "${STEP}  Install kernel   ${NO}"
cp -v linux-image-p4-64_5.4.40+-0_arm64.deb sdcard
cp -v pi4-64-bootloader_20200516-0_arm64.deb sdcard
chroot sdcard dpkg -i linux-image-p4-64_5.4.40+-0_arm64.deb
chroot sdcard dpkg -i pi4-64-bootloader_20200516-0_arm64.deb

#	########### Final setup		###########

echo -e "${STEP}  Allowing root to log into $release with password...  ${NO}"
sed -i 's/.*PermitRootLogin prohibit-password/PermitRootLogin yes/' sdcard/etc/ssh/sshd_config
#grep 'PermitRootLogin' sdcard/etc/ssh/sshd_config
cp -v bashrc.root sdcard/root/.bashrc

echo -e "${STEP}  sync'n debs ${NO}"
cp -nv sdcard/var/cache/apt/archives/*.deb debs

echo -e "${STEP}  Cleaning out archives   ${NO}"
du -h sdcard/var/cache/apt/archives | tail -1
rm -rf sdcard/var/cache/apt/archives/*
install -v -m 0755 -D Devuan-pi4_os64.sh sdcard/root/pi4-os64/Devuan-pi4_os64.sh
install -v -m 0644 vcgencmd.tar.xz sdcard/root/pi4-os64
install -v -m 0644 bashrc.root sdcard/root/pi4-os64
#install -v -m 0755 mini_image.sh sdcard/root
tar xvf vcgencmd.tar.xz -C sdcard || fail

sync
echo -e "${STEP}  Total sdcard used ${NO}"; echo
#du -h sdcard | tail -1
du -ch sdcard | grep total

echo -e "${STEP}\n  Unmounting mount points ${NO}"
umount -v sdcard/proc
umount -v sdcard/sys
umount -v sdcard/dev/pts
umount -v sdcard/boot
umount -v sdcard
rm -rvf sdcard
echo " "

echo $start_time
echo $(date)
echo " "

echo -e "${STEP}\n\n  Okie Dokie, We Done\n ${NO}"
echo -e "${DONE}  Y'all Have A Great Day now   ${NO}"
echo
