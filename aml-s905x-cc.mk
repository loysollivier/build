################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

# Need to set this before including common.mk
BUILDROOT_GETTY_PORT ?= ttyAML0

include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
ARM_TF_PATH		?= $(ROOT)/arm-trusted-firmware
ARM_TF_OUT		?= $(ARM_TF_PATH)/build/libretech/debug
ARM_TF_BOOT		?= $(ARM_TF_OUT)/armstub8.bin

OPTEE_PATH		?= $(ROOT)/optee_os
U-BOOT_PATH		?= $(ROOT)/u-boot
U-BOOT_BIN		?= $(U-BOOT_PATH)/u-boot.bin

LIBRETECH_FIRMWARE_PATH		?= $(BUILD_PATH)/libretech/firmware
LIBRETECH_STOCK_FW_PATH		?= $(ROOT)/firmware
LIBRETECH_STOCK_FW_PATH_BOOT	?= $(LIBRETECH_STOCK_FW_PATH)/boot

OPTEE_BIN		?= $(OPTEE_PATH)/out/arm/core/tee-header_v2.bin
OPTEE_BIN_EXTRA1	?= $(OPTEE_PATH)/out/arm/core/tee-pager_v2.bin
OPTEE_BIN_EXTRA2	?= $(OPTEE_PATH)/out/arm/core/tee-pageable_v2.bin

LINUX_IMAGE		?= $(LINUX_PATH)/arch/arm64/boot/Image
LINUX_DTB		?= $(LINUX_PATH)/arch/arm64/boot/dts/amlogic/meson-gxl-s905x-libretech-cc.dtb
MODULE_OUTPUT		?= $(ROOT)/module_output

################################################################################
# Targets
################################################################################
all: buildroot u-boot-amlogic-signed linux # arm-tf optee-os update_rootfs
clean: arm-tf-clean buildroot-clean u-boot-clean \
	optee-os-clean

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
ARM_TF_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

ARM_TF_FLAGS ?= \
	NEED_BL32=yes \
	BL32=$(OPTEE_BIN) \
	BL32_EXTRA1=$(OPTEE_BIN_EXTRA1) \
	BL32_EXTRA2=$(OPTEE_BIN_EXTRA2) \
	BL33=$(U-BOOT_BIN) \
	DEBUG=1 \
	V=0 \
	CRASH_REPORTING=1 \
	LOG_LEVEL=40 \
	PLAT=rpi3 \
	SPD=opteed

arm-tf: optee-os
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) all fip

arm-tf-clean:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) clean

################################################################################
# Das U-Boot
################################################################################

U-BOOT_EXPORTS ?= CROSS_COMPILE=$(AARCH64_CROSS_COMPILE) ARCH=arm64
U-BOOT_DEFCONFIG_COMMON_FILES := \
		$(U-BOOT_PATH)/configs/libretech-cc_defconfig \
		$(CURDIR)/kconfigs/u-boot_libretech.conf
.PHONY: u-boot-amlogic-signed
u-boot-amlogic-signed: u-boot
	mkdir -p $(U-BOOT_PATH)/fip
	cp $(LIBRETECH_STOCK_FW_PATH)/boot/gxl/bl2.bin $(U-BOOT_PATH)/fip/
	cp $(LIBRETECH_STOCK_FW_PATH)/boot/gxl/acs.bin $(U-BOOT_PATH)/fip/
	cp $(LIBRETECH_STOCK_FW_PATH)/boot/gxl/bl21.bin $(U-BOOT_PATH)/fip/
	cp $(LIBRETECH_STOCK_FW_PATH)/boot/gxl/bl30.bin $(U-BOOT_PATH)/fip/
	cp $(LIBRETECH_STOCK_FW_PATH)/boot/gxl/bl301.bin $(U-BOOT_PATH)/fip/
	cp $(LIBRETECH_STOCK_FW_PATH)/boot/gxl/bl31.bin $(U-BOOT_PATH)/fip/
	cp $(LIBRETECH_STOCK_FW_PATH)/boot/gxl/bl31.img $(U-BOOT_PATH)/fip/
	cp $(U-BOOT_PATH)/u-boot.bin $(U-BOOT_PATH)/fip/bl33.bin
	$(LIBRETECH_STOCK_FW_PATH)/boot/blx_fix.sh $(U-BOOT_PATH)/fip/bl30.bin $(U-BOOT_PATH)/fip/zero_tmp $(U-BOOT_PATH)/fip/bl30_zero.bin $(U-BOOT_PATH)/fip/bl301.bin $(U-BOOT_PATH)/fip/bl301_zero.bin $(U-BOOT_PATH)/fip/bl30_new.bin bl30
	$(LIBRETECH_STOCK_FW_PATH)/boot/acs_tool.pyc $(U-BOOT_PATH)/fip/bl2.bin $(U-BOOT_PATH)/fip/bl2_acs.bin $(U-BOOT_PATH)/fip/acs.bin 0
	$(LIBRETECH_STOCK_FW_PATH)/boot/blx_fix.sh $(U-BOOT_PATH)/fip/bl2_acs.bin $(U-BOOT_PATH)/fip/zero_tmp $(U-BOOT_PATH)/fip/bl2_zero.bin $(U-BOOT_PATH)/fip/bl21.bin $(U-BOOT_PATH)/fip/bl21_zero.bin $(U-BOOT_PATH)/fip/bl2_new.bin bl2
	$(LIBRETECH_STOCK_FW_PATH)/boot/gxl/aml_encrypt_gxl --bl3enc --input $(U-BOOT_PATH)/fip/bl30_new.bin
	$(LIBRETECH_STOCK_FW_PATH)/boot/gxl/aml_encrypt_gxl --bl3enc --input $(U-BOOT_PATH)/fip/bl31.img
	$(LIBRETECH_STOCK_FW_PATH)/boot/gxl/aml_encrypt_gxl --bl3enc --input $(U-BOOT_PATH)/fip/bl33.bin
	$(LIBRETECH_STOCK_FW_PATH)/boot/gxl/aml_encrypt_gxl --bl2sig --input $(U-BOOT_PATH)/fip/bl2_new.bin --output $(U-BOOT_PATH)/fip/bl2.n.bin.sig
	$(LIBRETECH_STOCK_FW_PATH)/boot/gxl/aml_encrypt_gxl --bootmk --output $(U-BOOT_PATH)/fip/u-boot.bin --bl2 $(U-BOOT_PATH)/fip/bl2.n.bin.sig --bl30 $(U-BOOT_PATH)/fip/bl30_new.bin.enc --bl31 $(U-BOOT_PATH)/fip/bl31.img.enc --bl33 $(U-BOOT_PATH)/fip/bl33.bin.enc
	# U-boot signed by Amlogic available in fip/ directory

u-boot: u-boot-defconfig
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) all
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) tools

u-boot-clean: u-boot-defconfig-clean
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

u-boot-defconfig: $(U-BOOT_DEFCONFIG_COMMON_FILES)
	cd $(U-BOOT_PATH) && \
		ARCH=arm64 \
		scripts/kconfig/merge_config.sh $(U-BOOT_DEFCONFIG_COMMON_FILES)

.PHONY: u-boot-defconfig-clean
u-boot-defconfig-clean:
	rm -f $(U-BOOT_PATH)/.config
################################################################################
# Busybox
################################################################################
BUSYBOX_COMMON_TARGET = libretech
BUSYBOX_CLEAN_COMMON_TARGET = libretech clean

busybox: busybox-common

busybox-clean: busybox-clean-common

busybox-cleaner: busybox-cleaner-common

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/defconfig \
		$(CURDIR)/kconfigs/libretech.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64

linux: linux-common
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(MODULE_OUTPUT) modules_install

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=rpi3
optee-os: optee-os-common

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=rpi3
optee-os-clean: optee-os-clean-common

################################################################################
# Root FS
################################################################################
.PHONY: update_rootfs
# Make sure this is built before the buildroot target which will create the
# root file system based on what's in $(BUILDROOT_TARGET_ROOT)
buildroot: update_rootfs
update_rootfs: linux u-boot-amlogic-signed #arm-tf
	@mkdir -p --mode=755 $(BUILDROOT_TARGET_ROOT)/boot
	@mkdir -p --mode=755 $(BUILDROOT_TARGET_ROOT)/usr/bin
	@install -v -p --mode=755 $(LINUX_DTB) $(BUILDROOT_TARGET_ROOT)/boot/meson-gxl-s905x-libretech-cc.dtb
	@install -v -p --mode=755 $(LINUX_IMAGE) $(BUILDROOT_TARGET_ROOT)/boot/Image
# This looks like the TF-A part that we should enable later on...
	# @install -v -p --mode=755 $(ARM_TF_BOOT) $(BUILDROOT_TARGET_ROOT)/boot/armstub8.bin
	@cd $(MODULE_OUTPUT) && find . | cpio -pudm $(BUILDROOT_TARGET_ROOT)

# Creating images etc, could wipe out a drive on the system, therefore we don't
# want to automate that in script or make target. Instead we just simply provide
# the steps here.
.PHONY: img-help
img-help:
	@echo "To install on blank SDCard (assuming SDCard in on /dev/sdx):"
	@echo ""
	@echo "run the following as root"
	@echo "   $$ mkfs.vfat /dev/sdx1"
	@echo "   $$ dd if=fip/u-boot.bin.sd.bin of=/dev/sdx conv=fsync,notrunc bs=1 count=444"
	@echo "   $$ dd if=fip/u-boot.bin.sd.bin of=/dev/sdx conv=fsync,notrunc bs=512 skip=1 seek=1"
	@echo "   $$ sync"
	@echo ""
	@echo "$$ fdisk /dev/sdx   # where sdx is the name of your sd-card"
	@echo "   > p             # prints partition table"
	@echo "   > d             # repeat until all partitions are deleted"
	@echo "   > n             # create a new partition"
	@echo "   > p             # create primary"
	@echo "   > 1             # make it the first partition"
	@echo "   > <enter>       # use the default sector"
	@echo "   > +32M          # create a boot partition with 32MB of space"
	@echo "   > n             # create rootfs partition"
	@echo "   > p"
	@echo "   > 2"
	@echo "   > <enter>"
	@echo "   > <enter>       # fill the remaining disk, adjust size to fit your needs"
	@echo "   > t             # change partition type"
	@echo "   > 1             # select first partition"
	@echo "   > e             # use type 'e' (FAT16)"
	@echo "   > a             # make partition bootable"
	@echo "   > 1             # select first partition"
	@echo "   > p             # double check everything looks right"
	@echo "   > w             # write partition table to disk."
	@echo ""
	@echo "run the following as root"
	@echo "   $$ mkfs.vfat -F16 -n BOOT /dev/sdx1"
	@echo "   $$ mkdir -p /media/boot"
	@echo "   $$ mount /dev/sdx1 /media/boot"
	@echo "   $$ cd /media"
	@echo "   $$ gunzip -cd $(ROOT)/out-br/images/rootfs.cpio.gz | sudo cpio -idmv \"boot/*\""
	@echo "   $$ umount boot"
	@echo ""
	@echo "run the following as root"
	@echo "   $$ mkfs.ext4 -L rootfs /dev/sdx2"
	@echo "   $$ mkdir -p /media/rootfs"
	@echo "   $$ mount /dev/sdx2 /media/rootfs"
	@echo "   $$ cd rootfs"
	@echo "   $$ gunzip -cd $(ROOT)/out-br/images/rootfs.cpio.gz | sudo cpio -idmv"
	@echo "   $$ rm -rf /media/rootfs/boot/*"
	@echo "   $$ cd .."
	@echo "   $$ umount /media/rootfs"
