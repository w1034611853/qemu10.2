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

log="${exe}.cmp_csel_gap.log"
nm_log="${exe}.cmp_csel_gap.nm"
block_dir="${exe}.cmp_csel_gap.blocks"
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
    local producer_addr
    local consumer_addr

    producer_addr=$(sym_addr "$producer_sym")
    consumer_addr=$(sym_addr "$consumer_sym")
    rg -q "A64 cmp-pending use producer_pc=0x${producer_addr} consumer_pc=0x${consumer_addr} age=${age} via=CSEL-pending" \
        "$log" || die "expected cmp-pending use for $label"
}

assert_retire()
{
    local label=$1
    local producer_sym=$2
    local consumer_sym=$3
    local age=$4
    local producer_addr
    local consumer_addr

    producer_addr=$(sym_addr "$producer_sym")
    consumer_addr=$(sym_addr "$consumer_sym")
    rg -q "A64 cmp-pending retire producer_pc=0x${producer_addr} consumer_pc=0x${consumer_addr} age=${age} via=CSEL-pending" \
        "$log" || die "expected cmp-pending retire for $label"
}

assert_no_use()
{
    local label=$1
    local producer_sym=$2
    local producer_addr

    producer_addr=$(sym_addr "$producer_sym")

    if rg -q "A64 cmp-pending (use|peek|retire) producer_pc=0x${producer_addr}\\b" \
        "$log"; then
        die "unexpected cmp-pending consume for $label"
    fi
}

assert_pending_positive()
{
    local label=$1
    local producer_sym=$2
    local consumer_sym=$3
    local age=$4

    assert_record "$label" "$producer_sym"
    assert_use "$label" "$producer_sym" "$consumer_sym" "$age"
    assert_retire "$label" "$producer_sym" "$consumer_sym" "$age"
}

extract_case_block()
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
        if (NR > start && /^----------------$/) {
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

assert_case_contains()
{
    local label=$1
    local case_sym=$2
    local pattern=$3
    local block

    block=$(extract_case_block "$label" "$case_sym")
    rg -q "$pattern" "$block" \
        || die "expected pattern '$pattern' in $label OP block"
}

assert_case_lacks()
{
    local label=$1
    local case_sym=$2
    local pattern=$3
    local block

    block=$(extract_case_block "$label" "$case_sym")
    if rg -q "$pattern" "$block"; then
        die "unexpected pattern '$pattern' in $label OP block"
    fi
}

assert_main_repr_positive()
{
    local label=$1
    local producer_sym=$2
    local consumer_sym=$3
    local op_pattern=$4

    assert_no_record "$label" "$producer_sym"
    assert_no_use "$label" "$producer_sym"
    assert_case_contains "$label" "$consumer_sym" 'x86_raw_flags'
    assert_case_contains "$label" "$consumer_sym" "$op_pattern"
    assert_case_lacks "$label" "$consumer_sym" '\b(NF|ZF|CF|VF)\b'
    assert_case_lacks "$label" "$consumer_sym" 'mov_i32 x86_flags_valid,\$0x0'
}

assert_main_repr_positive "cmp csel eq gap1" \
    cmp_csel_eq_gap1_producer cmp_csel_eq_gap1_consumer 'movcond_i64'
assert_main_repr_positive "cmp csel lt gap4" \
    cmp_csel_lt_gap4_producer cmp_csel_lt_gap4_consumer 'movcond_i64'
assert_main_repr_positive "cmp csel hi gap8" \
    cmp_csel_hi_gap8_producer cmp_csel_hi_gap8_consumer 'movcond_i64'
assert_main_repr_positive "cmp csel dst-is-cmp ne gap1" \
    cmp_csel_dst_is_cmp_ne_gap1_producer cmp_csel_dst_is_cmp_ne_gap1_consumer 'movcond_i64'
assert_main_repr_positive "cmp64 csel dst-is-lhs ls gap1" \
    cmp64_csel_dst_is_lhs_ls_gap1_producer cmp64_csel_dst_is_lhs_ls_gap1_consumer 'movcond_i64'
assert_main_repr_positive "cmp64 cset orr-shift ne gap1" \
    cmp64_cset_orr_shift_ne_gap1_producer cmp64_cset_orr_shift_ne_gap1_consumer 'setcond_i64'
assert_main_repr_positive "cmp64 csel hs chain gap1" \
    cmp64_csel_hs_chain_gap1_producer cmp64_csel_hs_chain_gap1_consumer 'movcond_i64'
assert_main_repr_positive "cmp64 cset orr-shift eq gap1" \
    cmp64_cset_orr_shift_eq_gap1_producer cmp64_cset_orr_shift_eq_gap1_consumer 'setcond_i64'
assert_main_repr_positive "cmp32 csel eq gap1" \
    cmp32_csel_eq_gap1_producer cmp32_csel_eq_gap1_consumer 'movcond_i64'
assert_main_repr_positive "cmp32 csel hi gap4" \
    cmp32_csel_hi_gap4_producer cmp32_csel_hi_gap4_consumer 'movcond_i64'
assert_main_repr_positive "cmp32 cset eq gap1" \
    cmp32_cset_eq_gap1_producer cmp32_cset_eq_gap1_consumer 'setcond_i64'
assert_main_repr_positive "cmp32 csel dst-is-false gap1" \
    cmp32_csel_dst_is_false_gap1_producer cmp32_csel_dst_is_false_gap1_consumer 'movcond_i64'
assert_main_repr_positive "cmp32 csel dst-is-true gap4" \
    cmp32_csel_dst_is_true_gap4_producer cmp32_csel_dst_is_true_gap4_consumer 'movcond_i64'
assert_main_repr_positive "cmp32 cset gt gap1" \
    cmp32_cset_gt_gap1_producer cmp32_cset_gt_gap1_consumer 'setcond_i64'
assert_main_repr_positive "cmp32 cset dst-is-cmp eq gap1" \
    cmp32_cset_dst_is_cmp_eq_gap1_producer cmp32_cset_dst_is_cmp_eq_gap1_consumer 'setcond_i64'
assert_main_repr_positive "cmp32 cset call eq gap1" \
    cmp32_cset_call_eq_gap1_producer cmp32_cset_call_eq_gap1_consumer 'setcond_i64'
assert_main_repr_positive "cmp32 cset call-reads-flags eq gap1" \
    cmp32_cset_call_reads_flags_eq_gap1_producer cmp32_cset_call_reads_flags_eq_gap1_consumer 'setcond_i64'
assert_main_repr_positive "cmp32 csel64 dst-is-false ne gap1" \
    cmp32_csel64_dst_is_false_ne_gap1_producer cmp32_csel64_dst_is_false_ne_gap1_consumer 'movcond_i64'
assert_main_repr_positive "cmp64 csel xzr eq gap1" \
    cmp64_csel_xzr_eq_gap1_producer cmp64_csel_xzr_eq_gap1_consumer 'movcond_i64'
assert_main_repr_positive "cmp64 csel pl gap1" \
    cmp64_csel_pl_gap1_producer cmp64_csel_pl_gap1_consumer 'movcond_i64'
assert_main_repr_positive "cmp64 csel mi gap1" \
    cmp64_csel_mi_gap1_producer cmp64_csel_mi_gap1_consumer 'movcond_i64'
assert_main_repr_positive "cmp32 cset ne gap1" \
    cmp32_cset_ne_gap1_producer cmp32_cset_ne_gap1_consumer 'setcond_i64'
assert_main_repr_positive "cmp32 cset ls gap1" \
    cmp32_cset_ls_gap1_producer cmp32_cset_ls_gap1_consumer 'setcond_i64'
assert_main_repr_positive "cmp64 cset pl gap1" \
    cmp64_cset_pl_gap1_producer cmp64_cset_pl_gap1_consumer 'setcond_i64'
assert_main_repr_positive "cmp64 cset mi gap1" \
    cmp64_cset_mi_gap1_producer cmp64_cset_mi_gap1_consumer 'setcond_i64'
assert_main_repr_positive "cmp csinc eq gap1" \
    cmp_csinc_eq_gap1_producer cmp_csinc_eq_gap1_consumer 'movcond_i64'
assert_main_repr_positive "cmp csinv eq gap4" \
    cmp_csinv_eq_gap4_producer cmp_csinv_eq_gap4_consumer 'movcond_i64'
assert_main_repr_positive "cmp csneg eq gap8" \
    cmp_csneg_eq_gap8_producer cmp_csneg_eq_gap8_consumer 'movcond_i64'
assert_main_repr_positive "cmp cset eq gap1" \
    cmp_cset_eq_gap1_producer cmp_cset_eq_gap1_consumer 'setcond_i64'
assert_main_repr_positive "cmp csetm hi gap4" \
    cmp_csetm_hi_gap4_producer cmp_csetm_hi_gap4_consumer 'negsetcond_i64'

assert_no_use "cmp csel bad gap" cmp_csel_bad_gap_producer

rg -q 'A64 cmp-pending summary tb_pc=0x' "$log" \
    || die "expected at least one cmp-pending summary marker"
