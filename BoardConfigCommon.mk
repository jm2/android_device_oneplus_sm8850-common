#
# Copyright (C) 2021-2025 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

COMMON_PATH := device/oneplus/sm8850-common

# A/B
AB_OTA_UPDATER := true

AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    init_boot \
    odm \
    product \
    pvmfw \
    recovery \
    system \
    system_dlkm \
    system_ext \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    vendor \
    vendor_boot \
    vendor_dlkm

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a-dotprod
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := oryon

# Audio
AUDIO_FEATURE_ENABLED_DLKM := true
AUDIO_FEATURE_ENABLED_EXTENDED_COMPRESS_FORMAT := true
AUDIO_FEATURE_ENABLED_GKI := true
AUDIO_FEATURE_ENABLED_INSTANCE_ID := true
AUDIO_FEATURE_ENABLED_MCS := true
AUDIO_FEATURE_ENABLED_SVA_MULTI_STAGE := true
BOARD_SUPPORTS_SOUND_TRIGGER := true
BOARD_USES_ALSA_AUDIO := true
TARGET_PROVIDES_AUDIO_HAL := true
TARGET_PROVIDES_LIBAGM := true
TARGET_PROVIDES_LIBAR_PAL := true

# Boot
BOARD_BOOT_HEADER_VERSION := 4
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_RAMDISK_USE_LZ4 := true

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := canoe

# DTB / DTBO
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_INCLUDE_RECOVERY_DTBO := true
ifeq ($(USE_PREBUILT_KERNEL), true)
BOARD_KERNEL_SEPARATED_DTBO := true
else
# OEM Kleaf source path: the dist ships dtbo.img already packed by the OEM build
# from all 8 board/panel variant overlays -- richer than re-packing the 2 flat
# .dtbo files kernel.mk's SEPARATED_DTBO rule would find. The adapter copies it
# into KERNEL_OUT and a vendor/lineage rule publishes it at this path for
# core/Makefile packaging + AVB signing (see kernel.mk "dist dtbo passthrough").
# MUST be deferred (=): TARGET_OUT_INTERMEDIATES is still empty while BoardConfig
# parses; an immediate := bakes in an absolute /KERNEL_OBJ/... path that panics
# soong's glob walk (filepath.Rel hits "/"). All consumers expand it later.
BOARD_PREBUILT_DTBOIMAGE = $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ/dtbo-dist.img
endif

# Filesystem
TARGET_FS_CONFIG_GEN := $(COMMON_PATH)/config.fs

# Init Boot
BOARD_INIT_BOOT_HEADER_VERSION := 4
BOARD_MKBOOTIMG_INIT_ARGS += --header_version $(BOARD_INIT_BOOT_HEADER_VERSION)

# Kernel
BOARD_BOOTCONFIG := \
    androidboot.hardware=qcom \
    androidboot.hypervisor.protected_vm.supported=true \
    androidboot.hypervisor.version=gunyah \
    androidboot.load_modules_parallel=true \
    androidboot.memcg=1 \
    androidboot.serialconsole=0 \
    androidboot.usbcontroller=a600000.dwc3 \
    androidboot.vendor.qspa=true

BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_KERNEL_PAGESIZE := 4096
BOARD_USES_GENERIC_KERNEL_IMAGE := true

TARGET_KERNEL_SOURCE := kernel/oneplus/sm8850
ifneq ($(USE_PREBUILT_KERNEL), true)
# --- OEM Kleaf source-kernel path (canoe_perf) -------------------------------
# Builds the OEM's exact kernel from source via the reusable vendor/lineage
# adapter (jm2 kernel.mk OEM-wrapper branch; see KLEAF_WIREUP_PLAN.md). This
# supersedes the legacy hand-translated Kbuild wiring (TARGET_KERNEL_CONFIG +
# TARGET_KERNEL_EXT_MODULES against kernel/oneplus/sm8850), which built a
# wrong-base ACK kernel (KMI skew) and is intentionally parked in git history
# / KLEAF_PIVOT.md. All of this lives inside !USE_PREBUILT_KERNEL, so the
# default prebuilt build (which boots today) is untouched.
TARGET_KERNEL_SOURCE := soc-repo
TARGET_KERNEL_VERSION := 6.12
TARGET_KERNEL_PLATFORM_TARGET := canoe_perf

# OEM repo root (where .repo lives). The bazel workspace + build wrapper live
# under it. This is the one per-sync-location knob -- env-overridable.
TARGET_KERNEL_PLATFORM_ROOT ?= /run/media/jmulesa/lineage/android/kernel-6.12
# Build driver: a jm2 wrapper that runs the OEM kernel build AND builds every
# //vendor/... canoe_perf DDK dist target against the same kernel_build (the OEM
# build alone covers only soc-repo/define_canoe -- no WLAN/display/audio/...),
# strips and merges everything into the kernel dist, and gates coverage against
# the stock load lists. See kernel-build/build-canoe-kleaf.sh + KLEAF_WIREUP_PLAN.md.
TARGET_KERNEL_PLATFORM_BUILD_WRAPPER := $(abspath $(COMMON_PATH))/kernel-build/build-canoe-kleaf.sh
TARGET_KERNEL_PLATFORM_BUILD_ARGS := canoe perf
TARGET_KERNEL_PLATFORM_DIST := kernel_platform/out/msm-kernel-canoe-perf/dist

# Module load lists: STOCK parity. These are the exact lists the proven prebuilt
# path uses (device/oneplus/infiniti-kernel/modules/*, extracted from the stock
# OTA) -- load membership AND order match the booting stock configuration; only
# the .ko provenance changes (source-built dist instead of OEM prebuilts). The
# build wrapper (kernel-build/build-canoe-kleaf.sh) delivers the full module set
# flat into the dist (kernel + all //vendor techpack DDK + GKI system_dlkm) and
# reports coverage against these same lists. .ko are flat in KERNEL_OUT, so the
# staged-set vars use basenames. Mirrors infiniti-kernel/BoardConfig.mk: the
# staged first-stage set is the recovery list (a superset of the normal list).
SM8850_STOCK_MODULES_PATH := device/oneplus/infiniti-kernel/modules
BOARD_SYSTEM_KERNEL_MODULES_LOAD := $(strip $(shell cat $(SM8850_STOCK_MODULES_PATH)/system_dlkm/modules.load 2>/dev/null))
BOARD_VENDOR_KERNEL_MODULES_LOAD := $(strip $(shell cat $(SM8850_STOCK_MODULES_PATH)/vendor_dlkm/modules.load 2>/dev/null))
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := $(SM8850_STOCK_MODULES_PATH)/vendor_dlkm/modules.blocklist
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := $(strip $(shell cat $(SM8850_STOCK_MODULES_PATH)/vendor_ramdisk/modules.load 2>/dev/null))
BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD := $(strip $(shell cat $(SM8850_STOCK_MODULES_PATH)/vendor_ramdisk/modules.load.recovery 2>/dev/null))
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_BLOCKLIST_FILE := $(SM8850_STOCK_MODULES_PATH)/vendor_ramdisk/modules.blocklist
# Staged first-stage set = the whole stock vendor_ramdisk DIRECTORY (mirrors the
# prebuilt path's $(wildcard ...) semantics), NOT just the load lists: stock
# stages dependency-only modules the lists never name (e.g. hdcp_qseecom_dlkm,
# which msm_drm needs at depmod/insmod time). Missing-from-dist names are
# skipped with a warning by kernel.mk under ALLOW_MISSING (jm2 patch 6).
BOOT_KERNEL_MODULES := $(sort $(notdir $(wildcard $(SM8850_STOCK_MODULES_PATH)/vendor_ramdisk/*.ko)))
SYSTEM_KERNEL_MODULES := $(notdir $(BOARD_SYSTEM_KERNEL_MODULES_LOAD))

# Stock lists may name a few modules this build doesn't produce yet; warn instead
# of hard-failing the build on a missing load-list entry (jm2 kernel.mk patch 4).
BOARD_KERNEL_MODULES_LOAD_ALLOW_MISSING := true
endif

# Metadata
BOARD_USES_METADATA_PARTITION := true

# Partitions
BOARD_PRODUCTIMAGE_MINIMAL_PARTITION_RESERVED_SIZE := false
-include vendor/lineage/config/BoardConfigReservedSize.mk
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_DTBOIMG_PARTITION_SIZE := 25165824
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_PVMFWIMAGE_PARTITION_SIZE := 1048576
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600
BOARD_USERDATAIMAGE_PARTITION_SIZE := 232843702272
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := odm product system system_dlkm system_ext vendor vendor_dlkm
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := $(shell echo $$(($(BOARD_SUPER_PARTITION_SIZE) - 4194304))) # (BOARD_SUPER_PARTITION_SIZE - "reasonable overhead of 4 MiB")
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
BOARD_FLASH_BLOCK_SIZE := 262144 # (BOARD_KERNEL_PAGESIZE * 64)
TARGET_COPY_OUT_ODM := odm
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm

# Platform
BOARD_USES_QCOM_HARDWARE := true
TARGET_BOARD_PLATFORM := canoe

# Properties
TARGET_ODM_PROP += $(COMMON_PATH)/odm.prop
TARGET_PRODUCT_PROP += $(COMMON_PATH)/product.prop
TARGET_SYSTEM_EXT_PROP += $(COMMON_PATH)/system_ext.prop
TARGET_VENDOR_PROP += $(COMMON_PATH)/vendor.prop

# Recovery
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
TARGET_RECOVERY_FSTAB := $(COMMON_PATH)/init/fstab.qcom
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# RIL
ENABLE_VENDOR_RIL_SERVICE := true

# Security
BOOT_SECURITY_PATCH := 2026-05-01
VENDOR_SECURITY_PATCH := $(BOOT_SECURITY_PATCH)

# SEPolicy
# jm2: org includes the (absent-in-our-tree) root device/qcom/sepolicy_vndr/SEPolicy.mk.
# Our sepolicy is checked out per-SoC (.../sm8850); the qcom-caf common pickup is the real
# dispatcher — it maps canoe (UM_6_12) -> sm8850/SEPolicy.mk AND pulls in
# device/lineage/sepolicy/qcom (which declares hal_lineage_livedisplay_qti et al.).
include hardware/qcom-caf/common/os_pickup_sepolicy_vndr.mk
include hardware/oplus/sepolicy/qti/SEPolicy.mk

# Verified Boot
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_MOVE_GSI_AVB_KEYS_TO_VENDOR_BOOT := true

BOARD_AVB_BOOT_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_BOOT_ALGORITHM := SHA256_RSA4096
BOARD_AVB_BOOT_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_BOOT_ROLLBACK_INDEX_LOCATION := 4

BOARD_AVB_DTBO_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_DTBO_ALGORITHM := SHA256_RSA4096
BOARD_AVB_DTBO_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_DTBO_ROLLBACK_INDEX_LOCATION := 3

BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1

BOARD_AVB_VBMETA_SYSTEM := system system_ext product pvmfw
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA4096
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 2

BOARD_AVB_VBMETA_VENDOR := odm vendor
BOARD_AVB_VBMETA_VENDOR_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_VBMETA_VENDOR_ALGORITHM := SHA256_RSA4096
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX_LOCATION := 5

# WiFi
BOARD_WLAN_DEVICE := qcwcn
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_$(BOARD_WLAN_DEVICE)
BOARD_WPA_SUPPLICANT_DRIVER := $(BOARD_HOSTAPD_DRIVER)
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := $(BOARD_HOSTAPD_PRIVATE_LIB)
BOARD_WPA_SUPPLICANT_PRIVATE_LIB_EVENT := "ON"
WIFI_DRIVER_STATE_CTRL_PARAM := "/dev/wlan"
WIFI_DRIVER_STATE_OFF := "OFF"
WIFI_DRIVER_STATE_ON := "ON"
WIFI_FEATURE_HOSTAPD_11AX := true
WIFI_HIDL_FEATURE_AWARE := true
WIFI_HIDL_FEATURE_DUAL_INTERFACE := true
WIFI_HIDL_UNIFIED_SUPPLICANT_SERVICE_RC_ENTRY := true
WPA_SUPPLICANT_VERSION := VER_0_8_X

# Include the proprietary files BoardConfig.
include vendor/oneplus/sm8850-common/BoardConfigVendor.mk
