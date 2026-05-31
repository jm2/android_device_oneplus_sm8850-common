# jm2/android_device_oneplus_sm8850-common — Lineage build notes

LineageOS 23.2 (Android 16, bp4a) device tree shared by OnePlus SM8850
devices. The infiniti-specific bits live alongside this in
`device/oneplus/infiniti/`.

## Quick start

```bash
# From the LineageOS root
source build/envsetup.sh
breakfast lineage_infiniti          # or lunch lineage_infiniti-bp4a-userdebug
mka kernel                          # kernel + modules only
# or
brunch infiniti                     # full build (boot.img / vendor.img / OTA zip)
```

## Upstream base — sm8850-devs (canoe) convergence

As of the 2026-05-30 convergence, this tree **rebases onto the
`OnePlus-SM8850-Development` ("sm8850-devs") `android_device_oneplus_sm8850-common`
canoe base** and carries only a thin overlay of our genuine deltas on top
(the `jm2` repo is now a true GitHub fork of the org, parent=org). The pre-convergence
independent tree is archived at `jm2/android_device_oneplus_sm8850-common-archive`.

The platform codename is **canoe** (SM8850, QTI `UM_6_12_FAMILY`). The earlier
`sm8850` (ad-hoc) and `sun` (= SM8750, previous chip) identifiers were stale-base
artifacts and are normalized to `canoe` — see `PROCESS.md`. API level is **36 / 202504**
(Android 16), inherited from the org base (was a stale `35 / 202404`).

Our overlay = KEEP-OURS for kernel-coupled files (we build a **source kernel**, the org
uses AOSP GKI): `BoardConfigCommon.mk` kernel section, `modules.*`, `dtbimg/dtboimg.mk`,
`tools/dtb/`; plus genuine adds (alert slider, composer-v4, our display HAL services,
`subsys_radio-V9` AIDL-skew fix, device configs). Everything below this line that
describes the **kernel/dtb** build is orthogonal to the convergence and still current.

## What this fork carries (kernel build)

The kernel-build configuration needed to drive the source-built kernel + hybrid
prebuilt module set. In commit order on the original tree:

- **`sm8850-common: kernel: build with system clang and genksyms workaround`** —
  switches `TARGET_KERNEL_CLANG_PATH` to `/usr` so the build uses
  Arch's clang 22 instead of an AOSP toolchain version that wasn't
  in the manifest. Adds the genksyms workaround config fragment to
  `TARGET_KERNEL_CONFIG`.

- **`sm8850-common: kernel: pass KCPPFLAGS=-I$(srctree) to the kernel build`** —
  vendor source uses quoted-include patterns like
  `#include "drivers/X/y.h"` that Kleaf resolves via injected `-I`s.
  We add the kernel source root to KCPPFLAGS so the same paths
  resolve under plain make.

- **`sm8850-common: kernel: KCPPFLAGS use $(abspath) instead of $(BUILD_TOP)`** —
  `$(BUILD_TOP)` is set in `vendor/lineage/config/BoardConfigKernel.mk`
  but `BoardConfigCommon.mk` is parsed first, so it was empty at the
  `:=`-immediate-expansion site — KCPPFLAGS ended up with a leading
  slash that clang rejected.

- **`sm8850-common: kernel: reorder datarmnet-ext/shs before perf*`** —
  `rmnet_perf.ko` and `rmnet_perf_tether.ko` consume
  `rmnet_shs.ko`'s Module.symvers; the build is sequential so the
  dependency must come first in `TARGET_KERNEL_EXT_MODULES`.

- **`sm8850-common: hybrid source-built + OEM-prebuilt module set`** —
  initial hybrid wiring: drop modules whose source-build was blocked
  on missing oplus extension source from `TARGET_KERNEL_EXT_MODULES`,
  and pull in the OEM prebuilt set from
  `device/oneplus/infiniti-kernel/` via `BOARD_VENDOR_KERNEL_MODULES`.
  Phases B and D below later restored display-drivers/msm,
  camera-kernel, and the seven oplus device-info entries to the
  source-built list.

- **`sm8850-common: fix system_dlkm load list for source-built kernel`** —
  removes `diag.ko` (not built and not in OEM prebuilt) and `gzvm.ko`
  (MTK GenieZone, irrelevant on Qualcomm); fixes the `clk_test.ko` →
  `clk-test.ko` naming mismatch; adds `netfs.ko`, `pwrseq-core.ko`,
  `clk_kunit_helpers.ko` as explicit load-list entries so depmod
  resolves system_dlkm symbols.

- **`sm8850-common: Phase B — add oplus boot helpers + standby_netlink
  to TARGET_KERNEL_EXT_MODULES`** — wires four new source-built oplus
  extension modules (oplus_bsp_cmdline_parser, oplus_bsp_bootmode,
  oplus_bsp_boot_projectinfo, oplus_standby_netlink). Together with
  the kernel-side Phase A Kconfig restorations, this resolves ~93 of
  the original 110 unresolved depmod symbols.

- **`sm8850-common: Phase C — exclude bad prebuilts, soft-fail load
  lists, auto-collect deps`** — three knobs that get `mka kernel` from
  depmod-clean to actually producing a kernel image:
  filter-out OEM `oplus_bsp_zram_opt.ko` and `oplus_bsp_sched_ext.ko`
  (need producers we haven't source-built yet — dispensable);
  `BOARD_KERNEL_MODULES_LOAD_ALLOW_MISSING := true` to soft-fail
  vendor's bloated load lists (sun/tuna/kera SoC variants we don't
  use); `TARGET_AUTO_COLLECT_KERNEL_MODULE_DEPS := true` to pull
  consumer→producer dep chains automatically into vendor_ramdisk.
  Together with kernel-side Phase C (camera-kernel SPECTRA_OPLUS, UFS
  CRYPTO QTI, arm64 gunyah Kconfig source) and the vendor/lineage
  ALLOW_MISSING patch, gets the build to **`mka kernel` exits 0**
  with a 39 MB ARM64 kernel Image and 568 modules in vendor_dlkm.

- **`sm8850-common: Phase D — add msm_drm + helpers to
  TARGET_KERNEL_EXT_MODULES`** — adds the four new source-built
  modules from Phase D: oplus device_info, touchpanel_notify,
  mm-drivers/hfi_core, and display-drivers/msm itself. With kernel-side
  Phase D (altmode-glink + panel_event_notifier + qti_pmic_glink) and
  modules-side Phase D (24 oplus/SM8850/*.c sources bundled into
  msm_drm.ko + 8 OPLUS_FEATURE_DISPLAY* defines), msm_drm.ko is now
  source-built with the full oplus display extension surface
  (oplus_display_ops, oplus_display_trace_enable, oplus_ofp_*,
  oplus_adfr_*, oplus_apuir_*, etc.).

- **`sm8850-common: Phase F — drop the filter-out, full prebuilt set in`** —
  with kernel-side Phase F resolving the last two unresolved symbols
  (`free_zram_is_ok` via in-tree stub linked into zram.ko;
  `__tracepoint_android_vh_scx_restore_flags` via DECLARE_HOOK +
  EXPORT_TRACEPOINT_SYMBOL_GPL), the BOARD_VENDOR_KERNEL_MODULES
  filter-out is no longer needed. Full 568 OEM prebuilts flow in.
  **Final result: 0 depmod symbol errors** (was 110 at start of
  Phase A). Per-phase audit lives in commit messages on
  `kernel/oneplus/sm8850`, `kernel/oneplus/sm8850-modules`, and this
  tree; see those READMEs for headline summaries.

- **`dtb: source-build dtb.img + dtbo.img for infiniti`** — custom
  recipes activated via `BOARD_CUSTOM_DTBIMG_MK` and
  `BOARD_CUSTOM_DTBOIMG_MK` hooks. dtb.img cats the 4 fat canoe
  SoC bases (built from canoe-{,v2,tp,tp-v2}-fat.dts wrappers in
  the sm8850-modules fork — see its Phase G). dtbo.img is a
  multi-DTBO image of project + board-MTP + selected techpack
  overlays, packaged via `mkdtboimg create`. ABL applies the dtbo
  overlays onto the matching dtb base at boot via FDT-internal
  qcom,msm-id / qcom,board-id / oplus,project-id matching, with
  correct symbol propagation. KBUILD_DTC_INCLUDE extended to a
  3-path list (audio-kernel, camera-kernel, synx-kernel) so the
  fat .dts wrappers' #includes resolve all dt-bindings headers.
  See `dtbimg.mk`, `dtboimg.mk`, and `tools/dtb/` for the recipes
  and oracle-diff tooling.

## DTB / DTBO source-build (Phase 5e of dtb_plan.md)

OEM ships dtb.img with SoC base DTBs (audio/sde/camera/eva/vidc/
gpu/dsp/etc. baked into each via DTC source-compose at build time)
and dtbo.img with project + techpack overlays (applied by ABL at
boot via correct symbol-propagating overlay resolution). This
fork mirrors that pattern.

- **`dtbimg.mk`** — `BOARD_CUSTOM_DTBIMG_MK` hook. Runs
  `make dtbs`, then cats the 4 source-composed canoe-*-fat.dtb
  files into `dtb.img`. ~2.2 MB total (4 FDTs).
- **`dtboimg.mk`** — `BOARD_CUSTOM_DTBOIMG_MK` hook with two
  modes via `INFINITI_DTBO_SOURCE`:
  - `source` (default): pack 11 selected techpack overlays via
    `mkdtboimg create` (canoe-mtp-overlay, canoe-mm-mtp,
    canoe-wcn786x-bt, canoe-ese, canoe-smem-mailbox, canoe-nfc,
    2 infiniti-canoe-overlay project bases, 2 infiniti-audio
    overlays, 1 infiniti-display overlay).
  - `oem`: copy OEM dtbo.img from a known dump path. Useful as
    an isolation step — our base + OEM overlays should boot if
    our base is correct, since canoe-fat.dtb's `__symbols__`
    matches OEM canoe.dtb (1922-1925/1923-1926).
- **`tools/dtb/`** — oracle-diff and packing tooling:
  - `inspect_dtb.py` (libfdt-based): four modes — `syms` dumps
    label→path, `symdiff` diffs label sets between two DTBs,
    `props` dumps full property set at a label, `propdiff` diffs
    properties for one or more labeled nodes (catches binding
    drift past pure label-set match).
  - `split_dtb.py`: splits a concatenated multi-FDT dtb.img by
    scanning for `0xd00dfeed` magic.
  - `select_techpack_dtbos.sh`: enumerates which `.dtbo` files to
    pack into dtbo.img (excluding ones already baked into the fat
    SoC bases). Used by `dtboimg.mk`.

`BoardConfigCommon.mk` carries the `BOARD_CUSTOM_DT*IMG_MK`
hooks and the extended `KBUILD_DTC_INCLUDE` 3-path list (audio-
kernel + camera-kernel + synx-kernel) needed for the fat .dts
wrappers' `#include` resolution. See the sm8850-modules fork's
Phase G section for the wrapper authoring + Makefile changes,
and `~/android/dtb_plan.md` for the architectural reframe story
that led to this design (the abandoned alternatives, why ABL is
the correct overlay-resolution layer, why fdtoverlay can't
substitute at build time).

## VINTF for Android 16 (FCM 202504)

Vendor blobs ship Android-15-era HAL versions; FCM 202504 bumps the
minimums. Three single-line patches across the device + qcom-caf
trees clear the `check_vintf_all` deprecation gate:

- Device VINTF manifest: now inherited from the sm8850-devs (canoe) base,
  already at `target-level="202504"`. The old `vintf/manifest_sun.xml`
  (`target-level="202404"`) was a sun-era artifact and is **dropped** in the
  convergence — the `202404`→`202504` bump is no longer ours to carry. (Historic
  symptom it caused: `check_vintf_all` "No kernel entry found for kernel version
  6.12 at kernel FCM version 202404" — kernel 6.12 only appears in FCM 202504.)
- `hardware/qcom-caf/sm8850/display/hal/composer/vendor.qti.hardware.display.composer-service3_v3.xml`:
  `<version>3</version>` → `<version>4</version>` for
  `android.hardware.graphics.composer3`. FCM 202504 deprecates @3.
- `hardware/qcom-caf/thermal/android.hardware.thermal-service.qti.xml`:
  `<version>2</version>` → `<version>3</version>` for
  `android.hardware.thermal`. FCM 202504 deprecates @2.

The HAL binaries actually implement the older versions; the
manifest bump is metadata-only. Framework calls go through binder
which queries `getInterfaceVersion()` at connect time and falls
back to the lower version, so v4-only methods just return
`STATUS_UNKNOWN_TRANSACTION` rather than crashing — same posture as
OxygenOS 16 ships with these blobs. Drop the bumps once vendor
publishes refreshed HAL impls.

## Audio (resolved by the sm8850-devs convergence)

**Superseded.** Previously `hardware/qcom-caf/sm8850/audio/` was a hand-populated,
manifest-untracked snapshot, and we carried an out-of-tree
`audio-vintf-disable.patch` adding `enabled: false` to the source HAL's
`prebuilt_etc` manifest fragments (the source shipped **v2 AIDL**, the extracted OEM
HAL binaries expect **v3** — see `extract-files.py` `replace_needed`
`audio.common-V1-ndk → V3-ndk` — and the mismatch dropped the audio HAL at VINTF
compat, causing a longish bootloop).

The convergence makes all of that moot: `audio/primary-hal` now tracks the
**`jm2/android_hardware_qcom_audio-ar`** fork of the org repo
(`lineage-23.2-caf-sm8850`), which is **configs-only** — `configs/canoe`,
`configs/alor`, no `hal/` source tree. There is no source audio HAL to disable, so the
`audio-vintf-disable.patch` is **dropped**, and the audio HAL is supplied entirely by
the OEM v3 prebuilts via `proprietary-files.txt`. `common.mk` inherits the canoe audio
configs (`sku_$(DEVICE_SKU)`) from the org base. The sun-era `sku_sun`/`configs/sun`
references are gone.

## Hybrid module set (post-Phase F)

| What | Where it comes from |
|------|---------------------|
| Kernel image (vmlinux, Image, dtb) | Source-built from `kernel/oneplus/sm8850/` |
| In-tree .ko (~190) | Source-built from `kernel/oneplus/sm8850/` |
| External .ko (34) | Source-built from `kernel/oneplus/sm8850-modules/` (Phase A+B added oplus_bsp_bootmode, oplus_bsp_cmdline_parser, oplus_bsp_boot_projectinfo, oplus_standby_netlink; Phase D added device_info, oplus_bsp_tp_notify, msm_hfi_core, msm_drm with oplus extensions) |
| In-tree .ko (~40) | Phase A+C+D+F kernel-side restorations (gunyah `gh_*` family, qcom_ramdump, mem-prot, icc-debug, qcom_pdr_msg, qcom_glink+memshare, ufshcd-crypto-qti, gh_arm_drv, qti_pmic_glink, altmode-glink, panel_event_notifier, hybridswap_stub, etc.) |
| External .ko (~534 others) | OEM prebuilt at `device/oneplus/infiniti-kernel/` — full 568-prebuilt set flows in cleanly after Phase F |

The wildcard `BOARD_VENDOR_KERNEL_MODULES += $(wildcard $(COMMON_PATH)/../infiniti-kernel/*.ko)`
pulls all 568 prebuilts in. Where the same `.ko` name is also
source-built, the source-built version overwrites at install time
because `vendor/lineage`'s kernel.mk runs depmod staging after the
prebuilt copy.

`MODVERSIONS=y` is kept on, so each prebuilt `.ko`'s `__versions`
section is validated against our kernel's `Module.symvers` at
modprobe time. Where a prebuilt fails the CRC check, edit
`modules.load` (in this directory) to skip it.

## Files of interest

- `BoardConfigCommon.mk` — `TARGET_KERNEL_*` build env (clang path,
  KCPPFLAGS, defconfig fragment list), `TARGET_KERNEL_EXT_MODULES`
  (source-built list), `BOARD_VENDOR_KERNEL_MODULES` (prebuilt
  wildcard).
- `modules.load` — runtime module load order. Names only; the .ko
  files come from either the source-built or prebuilt path above.
- `modules.load.recovery` — separate load list for recovery mode.
- `modules.load.system_dlkm` — system_dlkm partition load list.
- `modules.kunit` — KUnit test modules.
- `device/oneplus/infiniti-kernel/` (sibling, not a git repo) —
  the 568 OEM prebuilt `.ko` files extracted from OxygenOS's
  `vendor` partition. Kept intact and untouched by this fork.

## Companion repos

- [`jm2/android_kernel_oneplus_sm8850`](../../../kernel/oneplus/sm8850/) —
  kernel source tree. See its `README.lineage.md` for the
  genksyms prebuilt and the Phase A/B/C/D/F kernel-side patches.
- [`jm2/android_kernel_oneplus_sm8850-modules`](../../../kernel/oneplus/sm8850-modules/) —
  external module source tree. Its `README.md` lists the 30
  source-built externals and describes the build-system fixes.
- [`jm2/android_vendor_lineage`](../../../vendor/lineage/) — four
  patches against `build/tasks/kernel.mk` that this device tree
  depends on (modules-target wrapper fix, `BOARD_VENDOR_KERNEL_MODULES`
  merge, stale-oem wipe, soft-fail on missing
  `BOARD_*_KERNEL_MODULES_LOAD` entries). See `README.lineage-jm2.md`.
- [`jm2/android_hardware_qcom-caf_sm8850_display`](../../../hardware/qcom-caf/sm8850/display/) —
  display HAL fork carrying the composer3 manifest bump (@3→@4)
  for FCM 202504. Single one-line patch on top of the OEM CAF
  display tree.
- [`jm2/android_hardware_qcom_thermal`](../../../hardware/qcom-caf/thermal/) —
  thermal HAL fork carrying the manifest bump (@2→@3) for FCM 202504.
  Currently based on LineageOS; **slated to re-base onto the org thermal fork**
  in the convergence (the org's `android_hardware_qcom_thermal` diverges from
  LineageOS with sm8850 commits). Wired via `<remove-project>` + jm2 override in
  `.repo/local_manifests/infiniti.xml`.

### sm8850-devs forks (2026-05-30 convergence)

Forked from `OnePlus-SM8850-Development` to `jm2` so the org is upstream and our
changes layer on top (see the **Upstream base** section). Branch
`lineage-23.2` unless noted.

- `jm2/android_hardware_qcom_audio-ar` (`lineage-23.2-caf-sm8850`) — configs-only
  audio repo; replaces the hand-populated `audio/primary-hal` (canoe configs).
- `jm2/android_hardware_qcom-caf_common` — native `UM_6_12_FAMILY := canoe`; replaces
  our hand-patches `0001`/`0002` (dropped).
- `jm2/android_hardware_oplus` — org +7 sm8850 commits we lacked; the `0003`
  select-syntax fix migrates here as a fork commit.
- `jm2/android_hardware_lineage_compat` — org +3.
- `jm2/android_vendor_qcom_opensource_usb` — org +1.
- `jm2/android_device_oneplus_sm8850-common`, `…_infiniti` — re-forked from the org
  (were independent; old trees archived at `…-archive`).
- `jm2/android_device_qcom_sepolicy_vndr` (`lineage-23.2-caf-sm8850`) — org fork;
  being synced up to org HEAD.

`hardware/qcom-caf/sm8850/display` stays our independent `jm2` repo — the org
publishes no display repo.
