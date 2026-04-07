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

log="${exe}.logic_bcond.log"
nm_log="${exe}.logic_bcond.nm"
block_dir="${exe}.logic_bcond.blocks"
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

extract_case_block()
{
    local label=$1
    local branch_sym=$2
    local branch_addr
    local start_line
    local block

    branch_addr=$(sym_addr "$branch_sym")
    block="${block_dir}/${label}.op"
    start_line=$(rg -n -m1 "^ ---- 0*${branch_addr} " "$log" | cut -d: -f1) \
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
    ' "$log" >"$block" || die "failed to extract host block for $label"

    echo "$block"
}

assert_case_contains()
{
    local label=$1
    local branch_sym=$2
    local pattern=$3
    local block

    block=$(extract_case_block "$label" "$branch_sym")
    rg -q "$pattern" "$block" \
        || die "expected pattern '$pattern' in $label OP block"
}

assert_case_lacks()
{
    local label=$1
    local branch_sym=$2
    local pattern=$3
    local block

    block=$(extract_case_block "$label" "$branch_sym")
    if rg -q "$pattern" "$block"; then
        die "unexpected pattern '$pattern' in $label OP block"
    fi
}

assert_case_has_fallback_decode()
{
    local label=$1
    local branch_sym=$2
    local block

    block=$(extract_case_block "$label" "$branch_sym")
    rg -q 'and_i32 .*x86_raw_flags,\$0x[0-9a-f]+' "$block" \
        || die "expected raw-flags decode in $label OP block"
    rg -q 'brcond_i64' "$block" \
        || die "expected fallback brcond in $label OP block"
}

assert_case_contains "tst eq adjacent" tst_eq_adj_branch 'x86_jcc_i32'
assert_case_lacks "tst eq adjacent" tst_eq_adj_branch 'x86_raw_flags'
assert_case_lacks "tst eq adjacent" tst_eq_adj_branch 'brcond_i64'

assert_case_contains "ands mi adjacent" ands_mi_adj_branch 'x86_jcc_i32'
assert_case_lacks "ands mi adjacent" ands_mi_adj_branch 'x86_raw_flags'
assert_case_lacks "ands mi adjacent" ands_mi_adj_branch 'brcond_i64'

assert_case_contains "tst gt adjacent" tst_gt_adj_branch 'x86_jcc_i32'
assert_case_lacks "tst gt adjacent" tst_gt_adj_branch 'x86_raw_flags'
assert_case_lacks "tst gt adjacent" tst_gt_adj_branch 'brcond_i64'

assert_case_contains "tst32 mi adjacent" tst32_mi_adj_branch 'x86_jcc_i32'
assert_case_lacks "tst32 mi adjacent" tst32_mi_adj_branch 'x86_raw_flags'
assert_case_lacks "tst32 mi adjacent" tst32_mi_adj_branch 'brcond_i64'

assert_case_has_fallback_decode "tst eq gap" tst_eq_gap_branch

assert_case_lacks "tst vs adjacent" tst_vs_adj_branch 'x86_jcc_i32'
assert_case_lacks "tst vs adjacent" tst_vs_adj_branch 'x86_raw_flags'
assert_case_lacks "tst vs adjacent" tst_vs_adj_branch 'brcond_i64'

assert_case_lacks "tst cc adjacent" tst_cc_adj_branch 'x86_jcc_i32'
assert_case_lacks "tst cc adjacent" tst_cc_adj_branch 'x86_raw_flags'
assert_case_lacks "tst cc adjacent" tst_cc_adj_branch 'brcond_i64'
