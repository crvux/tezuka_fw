#!/bin/sh
# args from BR2_ROOTFS_POST_SCRIPT_ARGS
# $2    board name
set -e

BOARD_DIR=$(dirname ${0})

# Add a console on tty1
grep -qE '^ttyGS0::' ${TARGET_DIR}/etc/inittab || \
sed -i '/GENERIC_SERIAL/a\
ttyGS0::respawn:/sbin/getty -L ttyGS0 0 vt100 # USB console' ${TARGET_DIR}/etc/inittab

#ttyGS0 is not relevant and persistant on u-boot. As ACM seems to allows ONLY one serial, let use it as a general Serial link
#Rev C has a 2nd tty port plugged on usb power to have a full control

grep -qE '^::sysinit:/bin/mount -t debugfs' ${TARGET_DIR}/etc/inittab || \
sed -i '/hostname/a\
::sysinit:/bin/mount -t debugfs none /sys/kernel/debug/' ${TARGET_DIR}/etc/inittab

sed -i -e '/::sysinit:\/bin\/hostname -F \/etc\/hostname/d' ${TARGET_DIR}/etc/inittab

grep -q mtd2 ${TARGET_DIR}/etc/fstab || echo "mtd2 /mnt/jffs2 jffs2 rw,noatime 0 0" >> ${TARGET_DIR}/etc/fstab

# Prepare LICENSE.html
if [ ! -e ${BINARIES_DIR}/msd ]; then
	mkdir ${BINARIES_DIR}/msd
fi

cp ${BOARD_DIR}/LICENSE.template ${BINARIES_DIR}/msd/LICENSE.html
cp -r ${BOARD_DIR}/msd/* ${BINARIES_DIR}/msd/
LINUX_VERS=$(cat ${BR2_CONFIG} | grep '^BR2_LINUX_KERNEL_VERSION' | cut -d\" -f 2)
UBOOT_VERS=$(cat ${BR2_CONFIG} | grep '^BR2_TARGET_UBOOT_VERSION' | cut -d\" -f 2)
FW_VERSION=$(cd ${BOARD_DIR} && git describe --abbrev=4 --always --tags)
sed -i s/##DEVICE_FW##/${FW_VERSION}/g ${BINARIES_DIR}/msd/LICENSE.html
sed -i s/##LINUX_VERSION##/${LINUX_VERS}/g ${BINARIES_DIR}/msd/LICENSE.html
sed -i s/##UBOOT_VERSION##/${UBOOT_VERS}/g ${BINARIES_DIR}/msd/LICENSE.html

echo device-fw tezuka-${FW_VERSION}> ${TARGET_DIR}/opt/VERSIONS

BOARD_NAME="$(basename ${BOARD_DIR})"
GENIMAGE_CFG="${BOARD_DIR}/genimage-msd.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

rm -rf "${GENIMAGE_TMP}"

genimage                           \
	--rootpath "${TARGET_DIR}"     \
	--tmppath "${GENIMAGE_TMP}"    \
	--inputpath "${BINARIES_DIR}/msd"  \
	--outputpath "${TARGET_DIR}/opt/" \
	--config "${GENIMAGE_CFG}"

rm -f ${TARGET_DIR}/opt/boot.vfat
rm -f ${TARGET_DIR}/etc/init.d/S99iiod
rm -rf ${BINARIES_DIR}/msd

########################## ROOT FS INSTALL #############################

INSTALL=install

rm -Rf ${TARGET_DIR}/etc/dropbear

mkdir -p ${TARGET_DIR}/www/img
mkdir -p ${TARGET_DIR}/www/sweep
mkdir -p ${TARGET_DIR}/mnt/jffs2
mkdir -p ${TARGET_DIR}/mnt/msd
mkdir -p ${TARGET_DIR}/mnt/nfs
mkdir -p ${TARGET_DIR}/mnt/sd
mkdir -p ${TARGET_DIR}/etc/dropbear

${INSTALL} -D -m 0644 ${BOARD_DIR}/msd/img/* ${TARGET_DIR}/www/img/
${INSTALL} -D -m 0644 ${BOARD_DIR}/msd/sweep/* ${TARGET_DIR}/www/sweep/
${INSTALL} -D -m 0644 ${BOARD_DIR}/msd/*.* ${TARGET_DIR}/www/

ln -sf ../../wpa_supplicant/ifupdown.sh ${TARGET_DIR}/etc/network/if-up.d/wpasupplicant
ln -sf ../../wpa_supplicant/ifupdown.sh ${TARGET_DIR}/etc/network/if-down.d/wpasupplicant
ln -sf ../../wpa_supplicant/ifupdown.sh ${TARGET_DIR}/etc/network/if-pre-up.d/wpasupplicant
ln -sf ../../wpa_supplicant/ifupdown.sh ${TARGET_DIR}/etc/network/if-post-down.d/wpasupplicant

ln -sf device_reboot ${TARGET_DIR}/usr/sbin/pluto_reboot
