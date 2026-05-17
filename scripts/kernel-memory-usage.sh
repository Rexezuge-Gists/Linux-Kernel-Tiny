#!/usr/bin/env bash

set -euo pipefail

# =========================
# Linux Kernel Memory Usage
# =========================

# All results are in MB.

kb_to_mb() {
    awk "BEGIN { printf \"%.2f\", $1 / 1024 }"
}

read_meminfo() {
    local key="$1"
    awk -v k="$key" '$1 == k ":" { print $2 }' /proc/meminfo
}

echo "======================================="
echo " Linux Kernel Memory Usage Statistics"
echo "======================================="
echo

# -------------------------
# Base fields
# -------------------------

SLAB=$(read_meminfo Slab)
SRECLAIM=$(read_meminfo SReclaimable)
SUNRECLAIM=$(read_meminfo SUnreclaim)

KSTACK=$(read_meminfo KernelStack)
PAGETABLES=$(read_meminfo PageTables)
VMALLOC=$(read_meminfo VmallocUsed)

PERCpu=$(read_meminfo Percpu)

KRECLAIMABLE=$(read_meminfo KReclaimable)

# Some kernels do not expose these fields.
DIRECTMAP4K=$(read_meminfo DirectMap4k || echo 0)
DIRECTMAP2M=$(read_meminfo DirectMap2M || echo 0)
DIRECTMAP1G=$(read_meminfo DirectMap1G || echo 0)

# -------------------------
# Calculations
# -------------------------

DIRECTMAP_TOTAL=$((DIRECTMAP4K + DIRECTMAP2M + DIRECTMAP1G))

# Core kernel memory estimate.
# Does not include userspace process RSS.
KERNEL_TOTAL=$(( \
    SLAB + \
    KSTACK + \
    PAGETABLES + \
    VMALLOC + \
    PERCpu \
))

echo "Kernel Memory Breakdown:"
echo "---------------------------------------"

printf "%-25s %10s MB\n" "Slab:"              "$(kb_to_mb "$SLAB")"
printf "%-25s %10s MB\n" "  SReclaimable:"    "$(kb_to_mb "$SRECLAIM")"
printf "%-25s %10s MB\n" "  SUnreclaim:"      "$(kb_to_mb "$SUNRECLAIM")"

printf "%-25s %10s MB\n" "KernelStack:"       "$(kb_to_mb "$KSTACK")"
printf "%-25s %10s MB\n" "PageTables:"        "$(kb_to_mb "$PAGETABLES")"
printf "%-25s %10s MB\n" "VmallocUsed:"       "$(kb_to_mb "$VMALLOC")"
printf "%-25s %10s MB\n" "Percpu:"            "$(kb_to_mb "$PERCpu")"

echo

printf "%-25s %10s MB\n" "DirectMap Total:"   "$(kb_to_mb "$DIRECTMAP_TOTAL")"

echo
echo "---------------------------------------"

printf "%-25s %10s MB\n" \
    "Estimated Kernel Used:" \
    "$(kb_to_mb "$KERNEL_TOTAL")"

echo
echo "Notes:"
echo "  - Excludes user-space process RSS/VSZ"
echo "  - Includes slab/page tables/kernel stack/vmalloc/percpu"
echo "  - DirectMap is shown separately (physical mapping region)"
echo "  - Values are approximations from /proc/meminfo"
