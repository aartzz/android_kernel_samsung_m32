#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Kernel Build Configuration Script - OPTIMIZED FOR BORE + M32
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

#MGLRU TEST

disable_opt CONFIG_LRU_GEN

# ----------------------------------------------------------------------------
# CPU Scheduler (BORE + Full Preemption)
# ----------------------------------------------------------------------------
echo "[i] Unlocking BORE Power (Full Preemption)..."
set_opt CONFIG_SCHED_BORE
set_opt CONFIG_PREEMPT
disable_opt CONFIG_PREEMPT_VOLUNTARY
disable_opt CONFIG_PREEMPT_RT
disable_opt CONFIG_PREEMPT_NONE
disable_opt CONFIG_PRIO_LIMIT_HMP_BOOST
disable_opt CONFIG_MTK_SCHED_BOOST
disable_opt CONFIG_SEC_INPUT_BOOSTER_MTK
disable_opt CONFIG_SEC_INPUT_BOOSTER
disable_opt CONFIG_SCHED_HMP
disable_opt CONFIG_SCHED_HMP_PRIO_FILTER_VAL
disable_opt CONFIG_SCHEDSTATS
disable_opt CONFIG_RCU_TRACE
disable_opt CONFIG_ENABLE_DEFAULT_TRACERS
disable_opt CONFIG_MTK_SCHED_TRACERS
disable_opt CONFIG_SEC_DEBUG_TSP_LOG
disable_opt CONFIG_SEC_THERMAL_LOG
disable_opt CONFIG_SEC_DEBUG_SOFTDOG_PWDT
disable_opt CONFIG_MTK_IDLE_BALANCE_ENHANCEMENT
disable_opt CONFIG_CPU_FREQ_LIMIT
disable_opt CONFIG_MTK_SCHED_RQAVG_KS
disable_opt CONFIG_MTK_SCHED_RQAVG_US
disable_opt CONFIG_MTK_PERF_TRACKER
disable_opt CONFIG_MTK_TINYSYS_SSPM_DEBUG
disable_opt CONFIG_MTK_MUSB_QMU_SUPPORT
disable_opt CONFIG_MTK_MUSB_QMU_PURE_ZLP_SUPPORT


# ----------------------------------------------------------------------------
# Block I/O (Deadline + 128 Req Native)
# ----------------------------------------------------------------------------
echo "[i] Forcing Deadline I/O Scheduler..."
set_opt CONFIG_IOSCHED_DEADLINE
set_str CONFIG_DEFAULT_IOSCHED "deadline"
set_opt CONFIG_BLK_DEV_THROTTLING


# ----------------------------------------------------------------------------
# Hardware Kill-Switches (Morte do GOS e Throttling Samsung)
# ----------------------------------------------------------------------------
echo "[i] Disabling Samsung GOS/ABC/Thermal-Stats drivers..."
disable_opt CONFIG_SEC_ABC
disable_opt CONFIG_SEC_GAMESERVER
disable_opt CONFIG_SEC_GOS
disable_opt CONFIG_SEC_THERMAL_STATS
disable_opt CONFIG_SEC_DEBUG_THERMAL_LOG


# EAS & Scheduler Topology
set_opt CONFIG_SCHED_MC
set_opt CONFIG_MTK_SCHED_EAS
set_opt CONFIG_SCHED_ENERGY_AWARE
set_val CONFIG_SCHED_MIGRATION_COST 500000
set_opt CONFIG_UCLAMP_TASK


# PELT 16ms (Reaction speed)
set_opt CONFIG_PELT_UTIL_HALFLIFE_16
disable_opt CONFIG_PELT_UTIL_HALFLIFE_32

# ----------------------------------------------------------------------------
# MediaTek SoC Optimizations (Base Thermal & Mgmt)
# ----------------------------------------------------------------------------
echo "[i] Configuring MediaTek Base Subsystems..."
#Test WALT
disable_opt CONFIG_MTK_LOAD_TRACKER
set_opt CONFIG_SCHED_WALT

set_opt CONFIG_MTK_CPU_CTRL_CFP
disable_opt CONFIG_MTK_PERF_OBSERVER
disable_opt CONFIG_MTK_FPSGO_V3
set_opt CONFIG_RCU_NOCB_CPU
set_opt CONFIG_RCU_BOOST
set_val CONFIG_RCU_BOOST_DELAY 500
set_opt CONFIG_MTK_EARA
set_opt CONFIG_MTK_EARA_THERMAL
set_opt CONFIG_PNPMGR
set_opt CONFIG_MTK_PERFMGR
disable_opt CONFIG_MTK_RESYM
# Desativando conflitos com BORE e I/O Tweak
disable_opt CONFIG_MTK_EARA_AI
disable_opt CONFIG_MTK_IO_BOOST

# ----------------------------------------------------------------------------
# eBPF / CGROUP (Safe 4.14 Native)
# ----------------------------------------------------------------------------
echo "[i] Enabling Native eBPF subsystem..."
set_opt CONFIG_CGROUPS
set_opt CONFIG_CGROUP_BPF
set_opt CONFIG_BPF_SYSCALL
set_opt CONFIG_BPF_JIT
set_opt CONFIG_BPF_JIT_ALWAYS_ON
set_opt CONFIG_NET_CLS_BPF

# ----------------------------------------------------------------------------
# TCP Network (BBR + FQ Pacing)
# ----------------------------------------------------------------------------
echo "[i] Configuring TCP BBR + FQ..."
set_opt CONFIG_NET_SCH_FQ_CODEL
set_opt CONFIG_NET_SCH_FQ
set_opt CONFIG_TCP_CONG_BBR
disable_opt CONFIG_TCP_CONG_BIC
set_str CONFIG_DEFAULT_TCP_CONG "bbr"

#removing tcp cong trash

disable_opt CONFIG_TCP_CONG_CUBIC
disable_opt CONFIG_DEFAULT_CUBIC
disable_opt CONFIG_TCP_CONG_RENO
disable_opt CONFIG_DEFAULT_RENO
disable_opt CONFIG_TCP_CONG_WESTWOOD
disable_opt CONFIG_TCP_CONG_HTCP
disable_opt CONFIG_TCP_CONG_HYBLA
disable_opt CONFIG_TCP_CONG_VEGAS
disable_opt CONFIG_TCP_CONG_SCALABLE

# ----------------------------------------------------------------------------
# KernelSU & LTO
# ----------------------------------------------------------------------------
set_opt CONFIG_KSU
set_opt CONFIG_KSU_MANUAL_HOOK
set_opt CONFIG_LTO_CLANG
set_opt CONFIG_THINLTO



# ----------------------------------------------------------------------------
# Kernel Command Line (RCU Offload Injection)
# ----------------------------------------------------------------------------
echo "[i] Injecting rcu_nocbs=0-7 into cmdline..."
set_opt CONFIG_CMDLINE_EXTEND
set_str CONFIG_CMDLINE "rcu_nocbs=0-7"


# ----------------------------------------------------------------------------
# Final Serialization
# ----------------------------------------------------------------------------
echo "[i] Saving configuration to $DEFCONFIG..."
make O="$OUT_DIR" olddefconfig
make O="$OUT_DIR" savedefconfig
cp -v "$OUT_DIR/defconfig" "$DEFCONFIG_PATH"

echo ""
echo "✅ Done! BORE is now in PREEMPT mode."
echo "Run: bash build_kernel.sh"
