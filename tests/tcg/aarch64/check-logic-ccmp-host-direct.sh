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

log="${exe}.logic_ccmp.log"
nm_log="${exe}.logic_ccmp.nm"
block_dir="${exe}.logic_ccmp.blocks"
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

assert_case_contains "tst ccmp ne adjacent true" tst_ccmp_ne_adj_true_consumer \
    'x86_jcc'
assert_case_contains "tst ccmp ne adjacent true" tst_ccmp_ne_adj_true_consumer \
    'mov_i32 x86_raw_flags'
assert_case_lacks "tst ccmp ne adjacent true" tst_ccmp_ne_adj_true_consumer \
    'movcond_i32'
assert_case_lacks "tst ccmp ne adjacent true" tst_ccmp_ne_adj_true_consumer \
    'and_i32 .*x86_raw_flags'

assert_case_contains "tst ccmp ne adjacent false" tst_ccmp_ne_adj_false_consumer \
    'x86_jcc'
assert_case_contains "tst ccmp ne adjacent false" tst_ccmp_ne_adj_false_consumer \
    'mov_i32 x86_raw_flags'
assert_case_lacks "tst ccmp ne adjacent false" tst_ccmp_ne_adj_false_consumer \
    'movcond_i32'
assert_case_lacks "tst ccmp ne adjacent false" tst_ccmp_ne_adj_false_consumer \
    'and_i32 .*x86_raw_flags'

assert_case_contains "tst ccmn eq adjacent true" tst_ccmn_eq_adj_true_consumer \
    'x86_jcc'
assert_case_contains "tst ccmn eq adjacent true" tst_ccmn_eq_adj_true_consumer \
    'mov_i32 x86_raw_flags'
assert_case_lacks "tst ccmn eq adjacent true" tst_ccmn_eq_adj_true_consumer \
    'movcond_i32'
assert_case_lacks "tst ccmn eq adjacent true" tst_ccmn_eq_adj_true_consumer \
    'and_i32 .*x86_raw_flags'

assert_case_contains "tst ccmp eq gap" tst_ccmp_eq_gap_consumer \
    'movcond_i32'
assert_case_contains "tst ccmp eq gap" tst_ccmp_eq_gap_consumer \
    'and_i32 .*x86_raw_flags,\$0x4000'
assert_case_lacks "tst ccmp eq gap" tst_ccmp_eq_gap_consumer \
    'x86_jcc'
