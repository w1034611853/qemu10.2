#!/usr/bin/env bash

set -euo pipefail

die()
{
    echo "$@" 1>&2
    exit 1
}

[ $# -eq 2 ] || die "usage: $0 <qemu-bin> <exe>"

qemu_bin=$1
exe=$2
host_arch=$(uname -m)

case "$host_arch" in
    x86_64|i386|i486|i586|i686)
        ;;
    *)
        echo "skip: host arch $host_arch does not use i386 tcg backend"
        exit 0
        ;;
esac

log="${exe}.cmp_ccmp_bcond_chain.log"
nm_log="${exe}.cmp_ccmp_bcond_chain.nm"
block_dir="${exe}.cmp_ccmp_bcond_chain.blocks"
rm -f "$log" "$nm_log"
rm -rf "$block_dir"
mkdir -p "$block_dir"

"$qemu_bin" -d op,in_asm,nochain -D "$log" "$exe" >/dev/null 2>&1 \
    || die "running $exe under $qemu_bin failed"

nm -n "$exe" >"$nm_log" || die "failed to collect symbols for $exe"

sym_addr()
{
    local sym=$1

    awk -v sym="$sym" '
    $3 == sym {
        addr = tolower($1);
        sub(/^0+/, "", addr);
        if (addr == "") {
            addr = "0";
        }
        print addr;
        found = 1;
        exit 0;
    }
    END {
        exit(found ? 0 : 1);
    }
    ' "$nm_log" || die "failed to resolve symbol $sym in $exe"
}

extract_insn_block()
{
    local label=$1
    local case_sym=$2
    local case_addr
    local start_line
    local block

    case_addr=$(sym_addr "$case_sym")
    block="${block_dir}/${label}.op"
    start_line=$(rg -n -m1 "^ ---- 0*${case_addr} " "$log" | cut -d: -f1) \
        || die "failed to locate OP block for $label"

    awk -v start="$start_line" '
    NR >= start {
        if (NR > start && (/^ ---- / || /^----------------$/)) {
            exit 0;
        }
        print;
    }
    END {
        exit(start ? 0 : 1);
    }
    ' "$log" >"$block" || die "failed to extract OP block for $label"

    echo "$block"
}

assert_record()
{
    local label=$1
    local producer_sym=$2
    local producer_addr

    producer_addr=$(sym_addr "$producer_sym")
    rg -q "A64 cmp-pending record pc=0x${producer_addr}\\b" "$log" \
        || die "expected cmp-pending record for $label"
}

assert_no_record()
{
    local label=$1
    local producer_sym=$2
    local producer_addr

    producer_addr=$(sym_addr "$producer_sym")
    if rg -q "A64 cmp-pending record pc=0x${producer_addr}\\b" "$log"; then
        die "unexpected cmp-pending record for $label"
    fi
}

assert_use()
{
    local label=$1
    local producer_sym=$2
    local consumer_sym=$3
    local age=$4
    local via_pat=$5
    local producer_addr
    local consumer_addr

    producer_addr=$(sym_addr "$producer_sym")
    consumer_addr=$(sym_addr "$consumer_sym")
    rg -q "A64 cmp-pending use producer_pc=0x${producer_addr} consumer_pc=0x${consumer_addr} age=${age} via=${via_pat}" \
        "$log" || die "expected cmp-pending use for $label"
}

assert_no_use()
{
    local label=$1
    local producer_sym=$2
    local producer_addr

    producer_addr=$(sym_addr "$producer_sym")
    if rg -q "A64 cmp-pending (use|peek) producer_pc=0x${producer_addr}\\b" "$log"; then
        die "unexpected cmp-pending use for $label"
    fi
}

assert_retire()
{
    local label=$1
    local producer_sym=$2
    local consumer_sym=$3
    local age=$4
    local via_pat=$5
    local producer_addr
    local consumer_addr

    producer_addr=$(sym_addr "$producer_sym")
    consumer_addr=$(sym_addr "$consumer_sym")
    rg -q "A64 cmp-pending retire producer_pc=0x${producer_addr} consumer_pc=0x${consumer_addr} age=${age} via=${via_pat}" \
        "$log" || die "expected cmp-pending retire for $label"
}

assert_case_contains()
{
    local label=$1
    local case_sym=$2
    local pattern=$3
    local block

    block=$(extract_insn_block "$label" "$case_sym")
    rg -q "$pattern" "$block" \
        || die "expected pattern '$pattern' in $label OP block"
}

assert_case_lacks()
{
    local label=$1
    local case_sym=$2
    local pattern=$3
    local block

    block=$(extract_insn_block "$label" "$case_sym")
    if rg -q "$pattern" "$block"; then
        die "unexpected pattern '$pattern' in $label OP block"
    fi
}

assert_chain_positive()
{
    local label=$1
    local producer_sym=$2
    local ccmp_sym=$3
    local branch_sym=$4

    assert_record "$label old producer" "$producer_sym"
    assert_no_use "$label old producer" "$producer_sym"

    assert_record "$label new producer" "$ccmp_sym"
    assert_use "$label new producer" "$ccmp_sym" "$branch_sym" 1 \
        "B\\.cond-CCMP-pending"

    assert_case_lacks "$label ccmp block" "$ccmp_sym" 'mov_i32 x86_raw_flags'
}

assert_gap_fallback()
{
    local label=$1
    local producer_sym=$2
    local ccmp_sym=$3

    assert_record "$label old producer" "$producer_sym"
    assert_no_use "$label old producer" "$producer_sym"
    assert_no_record "$label new producer" "$ccmp_sym"
    assert_case_contains "$label ccmp block" "$ccmp_sym" 'mov_i32 x86_raw_flags'
}

assert_chain_positive \
    "cmp ccmp eq -> b.eq" \
    cmp_ccmp_eq_bcond_eq_chain_producer \
    cmp_ccmp_eq_bcond_eq_chain_ccmp \
    cmp_ccmp_eq_bcond_eq_chain_branch

assert_chain_positive \
    "cmp ccmp false-lit mi -> b.mi" \
    cmp_ccmp_false_lit_mi_bcond_mi_chain_producer \
    cmp_ccmp_false_lit_mi_bcond_mi_chain_ccmp \
    cmp_ccmp_false_lit_mi_bcond_mi_chain_branch

assert_chain_positive \
    "cmp ccmn hi -> b.eq" \
    cmp_ccmn_hi_bcond_eq_chain_producer \
    cmp_ccmn_hi_bcond_eq_chain_ccmp \
    cmp_ccmn_hi_bcond_eq_chain_branch

assert_gap_fallback \
    "cmp ccmp eq gap -> b.eq fallback" \
    cmp_ccmp_eq_bcond_eq_gap_producer \
    cmp_ccmp_eq_bcond_eq_gap_ccmp

rg -q 'A64 cmp-pending summary tb_pc=0x' "$log" \
    || die "expected at least one cmp-pending summary marker"
