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

log="${exe}.cmp_bcond_gap.log"
nm_log="${exe}.cmp_bcond_gap.nm"
block_dir="${exe}.cmp_bcond_gap.blocks"
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

extract_op_block()
{
    local label=$1
    local branch_sym=$2
    local branch_addr
    local start_line
    local block

    branch_addr=$(sym_addr "$branch_sym")
    block="${block_dir}/${label}.op"
    start_line=$(rg -n -m1 "^ ---- 0*${branch_addr} " \
        "$log" | cut -d: -f1) || die "failed to locate host block for $label"

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
    ' "$log" >"$block" || die "failed to extract host block for $label"

    echo "$block"
}

assert_case_contains()
{
    local label=$1
    local branch_sym=$2
    local pattern=$3
    local block

    block=$(extract_op_block "$label" "$branch_sym")
    rg -q "$pattern" "$block" \
        || die "expected pattern '$pattern' in $label OP block"
}

assert_case_lacks()
{
    local label=$1
    local branch_sym=$2
    local pattern=$3
    local block

    block=$(extract_op_block "$label" "$branch_sym")
    if rg -q "$pattern" "$block"; then
        die "unexpected pattern '$pattern' in $label OP block"
    fi
}

assert_main_rep_branch_block()
{
    local label=$1
    local branch_sym=$2

    assert_case_contains "$label" "$branch_sym" 'x86_raw_flags'
    assert_case_contains "$label" "$branch_sym" 'brcond_i64'
    assert_case_lacks "$label" "$branch_sym" \
        'x86_(cmp|add|adc)_(brcond|jcc|hi_jcc|ls_jcc)_capture_rawflags'
    assert_case_lacks "$label" "$branch_sym" 'mov_i32 x86_cc_op'
}

assert_adjacent_direct_branch_block()
{
    local label=$1
    local branch_sym=$2

    assert_case_contains "$label" "$branch_sym" \
        'x86_(cmp|add|adc)_(brcond|jcc|hi_jcc|ls_jcc)_capture_rawflags'
    assert_case_lacks "$label" "$branch_sym" 'brcond_i64'
    assert_case_lacks "$label" "$branch_sym" 'and_i32 .*x86_raw_flags'
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

assert_use()
{
    local label=$1
    local producer_sym=$2
    local branch_sym=$3
    local age=$4
    local producer_addr
    local branch_addr

    producer_addr=$(sym_addr "$producer_sym")
    branch_addr=$(sym_addr "$branch_sym")
    rg -q "A64 cmp-pending use producer_pc=0x${producer_addr} consumer_pc=0x${branch_addr} age=${age} via=B\\.cond-x86-(tcg|jcc)" \
        "$log" || die "expected cmp-pending use for $label"
}

assert_rewind()
{
    local label=$1
    local producer_sym=$2
    local branch_sym=$3
    local age=$4
    local producer_addr
    local branch_addr

    producer_addr=$(sym_addr "$producer_sym")
    branch_addr=$(sym_addr "$branch_sym")
    rg -q "A64 cmp-pending rewind producer_pc=0x${producer_addr} consumer_pc=0x${branch_addr} age=${age} via=B\\.cond-x86-(tcg|jcc)" \
        "$log" || die "expected cmp-pending rewind for $label"
}

assert_no_use()
{
    local label=$1
    local producer_sym=$2
    local producer_addr

    producer_addr=$(sym_addr "$producer_sym")

    if rg -q "A64 cmp-pending use producer_pc=0x${producer_addr}\\b" "$log"; then
        die "unexpected cmp-pending use for $label"
    fi

    if rg -q "A64 cmp-pending rewind producer_pc=0x${producer_addr}\\b" "$log"; then
        die "unexpected cmp-pending rewind for $label"
    fi
}

assert_drop()
{
    local label=$1
    local producer_sym=$2
    local producer_addr

    producer_addr=$(sym_addr "$producer_sym")
    rg -q "A64 cmp-pending drop producer_pc=0x${producer_addr}\\b" "$log" \
        || die "expected cmp-pending drop for $label"
}

assert_recorded_drop()
{
    local label=$1
    local producer_sym=$2

    assert_record "$label" "$producer_sym"
    assert_no_use "$label" "$producer_sym"
    assert_drop "$label" "$producer_sym"
}

assert_direct_positive()
{
    local label=$1
    local producer_sym=$2
    local branch_sym=$3
    local age=$4

    assert_record "$label" "$producer_sym"
    assert_use "$label" "$producer_sym" "$branch_sym" "$age"
    assert_adjacent_direct_branch_block "$label" "$branch_sym"
}

assert_main_rep_positive()
{
    local label=$1
    local producer_sym=$2
    local branch_sym=$3

    assert_record "$label" "$producer_sym"
    assert_no_use "$label" "$producer_sym"
    assert_main_rep_branch_block "$label" "$branch_sym"
}

assert_main_rep_unrecorded_positive()
{
    local label=$1
    local producer_sym=$2
    local branch_sym=$3

    assert_no_use "$label" "$producer_sym"
    assert_main_rep_branch_block "$label" "$branch_sym"
}

assert_main_rep_positive "cmp gap1" cmp_gap1_producer cmp_gap1_branch
assert_main_rep_positive "subs gap4" subs_gap4_producer subs_gap4_branch
assert_main_rep_positive "cmp gap8" cmp_gap8_producer cmp_gap8_branch
assert_main_rep_positive "cmn gap1" cmn_gap1_producer cmn_gap1_branch
assert_main_rep_positive "adds gap4" adds_gap4_producer adds_gap4_branch
assert_main_rep_positive "cmn gap8" cmn_gap8_producer cmn_gap8_branch
assert_main_rep_positive "cmn cs gap1" cmn_cs_gap1_producer cmn_cs_gap1_branch
assert_main_rep_positive "adds cc gap1" adds_cc_gap1_producer adds_cc_gap1_branch
assert_main_rep_positive "cmn hi gap4" cmn_hi_gap4_producer cmn_hi_gap4_branch
assert_main_rep_positive "adds ls gap4" adds_ls_gap4_producer adds_ls_gap4_branch
assert_main_rep_positive "cmn vs gap1" cmn_vs_gap1_producer cmn_vs_gap1_branch
assert_main_rep_positive "adds vc gap4" adds_vc_gap4_producer adds_vc_gap4_branch
assert_main_rep_positive "cmn mi gap4" cmn_mi_gap4_producer cmn_mi_gap4_branch
assert_main_rep_positive "adds pl gap1" adds_pl_gap1_producer adds_pl_gap1_branch
assert_main_rep_positive "adcs cs gap1" adcs_cs_gap1_producer adcs_cs_gap1_branch
assert_main_rep_positive "adcs cc gap1" adcs_cc_gap1_producer adcs_cc_gap1_branch
assert_main_rep_positive "adcs hi gap4" adcs_hi_gap4_producer adcs_hi_gap4_branch
assert_main_rep_positive "adcs ls gap4" adcs_ls_gap4_producer adcs_ls_gap4_branch
assert_main_rep_positive "adcs eq gap1" adcs_eq_gap1_producer adcs_eq_gap1_branch
assert_main_rep_positive "adcs vs gap4" adcs_vs_gap4_producer adcs_vs_gap4_branch
assert_main_rep_positive "adcs rd eq gap1" adcs_rd_eq_gap1_producer adcs_rd_eq_gap1_branch
assert_main_rep_positive "adcs rd cs gap1" adcs_rd_cs_gap1_producer adcs_rd_cs_gap1_branch
assert_main_rep_positive "adcs rd vs gap4" adcs_rd_vs_gap4_producer adcs_rd_vs_gap4_branch
assert_main_rep_positive "adcs rd hi gap4" adcs_rd_hi_gap4_producer adcs_rd_hi_gap4_branch
assert_main_rep_positive "sbcs rd cs gap1" sbcs_rd_cs_gap1_producer sbcs_rd_cs_gap1_branch
assert_main_rep_positive "sbcs rd mi gap4" sbcs_rd_mi_gap4_producer sbcs_rd_mi_gap4_branch
assert_main_rep_positive "adcs32 rd eq gap1" adcs32_rd_eq_gap1_producer adcs32_rd_eq_gap1_branch
assert_main_rep_positive "sbcs32 rd mi gap4" sbcs32_rd_mi_gap4_producer sbcs32_rd_mi_gap4_branch

assert_main_rep_unrecorded_positive "non-whitelist gap" cmp_bad_gap_producer cmp_bad_gap_branch
assert_main_rep_unrecorded_positive "flags writer gap" cmp_flags_writer_producer cmp_flags_writer_branch
assert_main_rep_unrecorded_positive "gap overflow" cmp_gap9_producer cmp_gap9_branch
assert_main_rep_unrecorded_positive "page boundary" cmp_page_boundary_producer cmp_page_boundary_branch
assert_no_use "direct control-flow cut" cmp_direct_cut_producer

assert_record "adjacent precedence" cmp_adjacent_precedence_producer
assert_use "adjacent precedence" cmp_adjacent_precedence_producer \
    cmp_adjacent_precedence_branch 1
assert_adjacent_direct_branch_block "adjacent precedence" cmp_adjacent_precedence_branch

rg -q 'A64 cmp-pending record pc=0x' "$log" \
    || die "expected at least one cmp-pending record marker"
rg -q 'A64 cmp-pending use producer_pc=0x' "$log" \
    || die "expected at least one cmp-pending use marker"
rg -q 'A64 cmp-pending summary tb_pc=0x' "$log" \
    || die "expected at least one cmp-pending summary marker"
