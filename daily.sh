#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Kernel Build Configuration Script - OPTIMIZED FOR BORE + M32 + 90Hz UI
# Target: MT6769V (Samsung M32)
# Toolchain: Clang 21 + ThinLTO
# ============================================================================

export PATH="$(pwd)/clang/bin:$PATH"
export LD=ld.lld
export CC=clang
export CROSS_COMPILE=aarch64-linux-gnu-

KERNEL_DIR="$(pwd)"
OUT_DIR="$KERNEL_DIR/out"
DEFCONFIG="rsuntk_defconfig"
DEFCONFIG_PATH="$KERNEL_DIR/arch/arm64/configs/$DEFCONFIG"
SCRIPTS_CONFIG="$KERNEL_DIR/scripts/config"

echo "[i] daily.sh: Initializing build configuration..."

# Helper Functions
set_opt() { "$SCRIPTS_CONFIG" --file "$OUT_DIR/.config" --enable "$1" || true; }
disable_opt() { "$SCRIPTS_CONFIG" --file "$OUT_DIR/.config" --disable "$1" || true; }
set_str() { "$SCRIPTS_CONFIG" --file "$OUT_DIR/.config" --set-str "$1" "$2" || true; }
set_val() { "$SCRIPTS_CONFIG" --file "$OUT_DIR/.config" --set-val "$1" "$2" || true; }

# Initialize Clean Config
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
cp "$DEFCONFIG_PATH" "$OUT_DIR/.config"
make O="$OUT_DIR" olddefconfig

# ----------------------------------------------------------------------------
# Block & Compression Subsystem (ZRAM/LZ4 Performance)
# ----------------------------------------------------------------------------
echo "[i] Configuring ZRAM Performance..."
set_opt CONFIG_ZRAM
disable_opt CONFIG_ZRAM_WRITEBACK
set_opt CONFIG_ZSMALLOC
set_opt CONFIG_ZSMALLOC_STAT
disable_opt CONFIG_ZRAM_DEF_COMP_LZO
set_opt CONFIG_ZRAM_DEF_COMP_LZ4
set_opt CONFIG_CRYPTO_LZ4
set_opt CONFIG_RD_LZ4
disable_opt CONFIG_LRU_GEN

# ----------------------------------------------------------------------------
# CPU Scheduler (BORE + Full Preemption + 90Hz UI Snappiness)
# ----------------------------------------------------------------------------
echo "[i] Unlocking BORE Power & 90Hz UI Boost..."
set_opt CONFIG_SCHED_BORE
set_opt CONFIG_PREEMPT
disable_opt CONFIG_PREEMPT_VOLUNTARY
disable_opt CONFIG_PREEMPT_RT
disable_opt CONFIG_PREEMPT_NONE
disable_opt CONFIG_PRIO_LIMIT_HMP_BOOS

disable_opt CONFIG_NO_HZ_FULL
set_opt CONFIG_NO_HZ_IDLE

set_opt CONFIG_SEC_INPUT_BOOSTER
set_opt CONFIG_SEC_INPUT_BOOSTER_MTK
set_opt CONFIG_MTK_SCHED_BOOST
set_opt CONFIG_MTK_SCHED_INTERACTION_BOOST
set_opt CONFIG_SCHED_TUNE
disable_opt CONFIG_WQ_POWER_EFFICIENT_DEFAULT

disable_opt CONFIG_SCHED_HMP
disable_opt CONFIG_SCHEDSTATS
disable_opt CONFIG_ENABLE_DEFAULT_TRACERS
disable_opt CONFIG_MTK_SCHED_TRACERS

# WALT+BORE: nenhum PELT halflife deve estar ativo
# PELT ainda computa para cgroups/uclamp mas sem halflife forçado
disable_opt CONFIG_PELT_UTIL_HALFLIFE_16
disable_opt CONFIG_PELT_UTIL_HALFLIFE_32

# EAS migration cost otimizado para MT6769 big.LITTLE (4xA75 + 4xA55)
# 500us: reduz migracoes desnecessarias sem travar tasks no cluster errado
set_val CONFIG_SCHED_MIGRATION_COST 500000

# ----------------------------------------------------------------------------
# Binder IPC
# ----------------------------------------------------------------------------
echo "[i] Tuning Binder IPC..."
set_opt CONFIG_ANDROID_BINDER_IPC
set_opt CONFIG_ANDROID_BINDERFS
# 384 paginas = 1.5MB: cobre gaming pesado (Unity/Unreal) sem desperdicar RAM
set_val CONFIG_ANDROID_BINDER_MAX_ALLOC_PAGES 384
disable_opt CONFIG_ANDROID_BINDER_IPC_SELFTEST

# ----------------------------------------------------------------------------
# Block I/O (Deadline para eMMC 5.1 SQ)
# eMMC 5.1 expoe Single Queue — BFQ gera overhead de fila por processo sem
# ganho real pois o HW serializa tudo em uma unica fila de hardware.
# Deadline garante anti-starvation de reads (read_expire=500ms) e write
# batching (write_starved=2) ideal para F2FS sequential workload.
# ----------------------------------------------------------------------------
echo "[i] Setting Deadline I/O Scheduler for eMMC 5.1 SQ..."
set_opt CONFIG_IOSCHED_DEADLINE
set_str CONFIG_DEFAULT_IOSCHED "deadline"
disable_opt CONFIG_IOSCHED_BFQ
set_opt CONFIG_BLK_DEV_THROTTLING

# ----------------------------------------------------------------------------
# Hardware Kill-Switches & Silencing
# ----------------------------------------------------------------------------
echo "[i] Disabling Samsung GOS/ABC/Thermal-Stats..."
set_opt CONFIG_SEC_ABC
set_opt CONFIG_SEC_GOS
set_opt CONFIG_SEC_THERMAL_STATS
disable_opt CONFIG_SEC_GAMESERVER
disable_opt CONFIG_MTK_PTPOD
disable_opt CONFIG_MTK_THERMAL_PTPOD

set_val CONFIG_CONSOLE_LOGLEVEL_DEFAULT 4
set_val CONFIG_MESSAGE_LOGLEVEL_DEFAULT 4
disable_opt CONFIG_DYNAMIC_DEBUG
disable_opt CONFIG_FUNCTION_TRACER
disable_opt CONFIG_MALI_BIFROST_DEBUG
disable_opt CONFIG_MALI_BIFROST_ERROR_DUMP
disable_opt CONFIG_SEC_ST_GPU_LOW_TEMP_LIMIT

# cgroup debug: overhead em toda operacao de cgroup (Mali, GED, tasks)
disable_opt CONFIG_CGROUP_DEBUG

# ----------------------------------------------------------------------------
# RCU Performance (NOCB offload para 90Hz jitter reduction)
# ----------------------------------------------------------------------------
echo "[i] Forcing RCU NOCB Offload..."
set_opt CONFIG_RCU_EXPERT
set_opt CONFIG_RCU_NOCB_CPU
set_opt CONFIG_RCU_NOCB_CPU_ALL
set_opt CONFIG_RCU_BOOST
# 100ms: responsivo para UI 90Hz (500ms anterior causava jitter em IRQ paths)
set_val CONFIG_RCU_BOOST_DELAY 100
set_val CONFIG_RCU_CPU_STALL_TIMEOUT 120
disable_opt CONFIG_RCU_TRACE

# ----------------------------------------------------------------------------
# Virtual Memory
# ----------------------------------------------------------------------------
echo "[i] Tuning Virtual Memory..."
disable_opt CONFIG_CMDLINE_FORCE
set_opt CONFIG_CMDLINE_EXTEND
set_str CONFIG_CMDLINE "rcu_nocbs=6-7 vmalloc=448M"

# ----------------------------------------------------------------------------
# Mali G52 MC2 — TLB efficiency
# ----------------------------------------------------------------------------
echo "[i] Enabling Mali G52 MC2 TLB optimizations..."
set_opt CONFIG_MALI_EXPERT
set_opt CONFIG_MALI_2MB_ALLOC

# ----------------------------------------------------------------------------
# TCP Network (BBR + FQ Pacing)
# ----------------------------------------------------------------------------
set_opt CONFIG_NET_SCH_FQ
set_opt CONFIG_TCP_CONG_BBR
set_str CONFIG_DEFAULT_TCP_CONG "bbr"

# ----------------------------------------------------------------------------
# KernelSU & LTO
# ----------------------------------------------------------------------------
set_opt CONFIG_KSU
set_opt CONFIG_KSU_MANUAL_HOOK
set_opt CONFIG_LTO_CLANG
set_opt CONFIG_THINLTO

# ----------------------------------------------------------------------------
# Final Serialization
# ----------------------------------------------------------------------------
echo "[i] Saving configuration to $DEFCONFIG..."
make O="$OUT_DIR" olddefconfig
make O="$OUT_DIR" savedefconfig
cp -v "$OUT_DIR/defconfig" "$DEFCONFIG_PATH"

echo ""
echo "✅ Done! daily.sh: BORE + RCU NOCB + Deadline(SQ) + G52 TLB + EAS tuned."
