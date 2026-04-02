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

log="${exe}.logic_csel_ccmp_gap.log"
nm_log="${exe}.logic_csel_ccmp_gap.nm"
rm -f "$log"
rm -f "$nm_log"

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

assert_no_cmp_pending()
{
    local label=$1
    local producer_sym=$2
    local producer_addr

    producer_addr=$(sym_addr "$producer_sym")

    if rg -q "A64 cmp-pending (record|use|peek) producer_pc=0x${producer_addr}\\b" \
        "$log"; then
        die "unexpected cmp-pending path for $label"
    fi
}

assert_no_cmp_pending "tst csel eq gap1" tst_csel_eq_gap1_case
assert_no_cmp_pending "ands csel mi gap4" ands_csel_mi_gap4_case
assert_no_cmp_pending "tst ccmp true gap1" tst_ccmp_true_gap1_case
assert_no_cmp_pending "ands ccmp false gap4" ands_ccmp_false_gap4_case

rg -q 'x86_test_capture_rawflags_i64' "$log" \
    || die "expected logical raw-flags capture op"
rg -q 'movcond_i64' "$log" \
    || die "expected movcond path for logical -> CSEL cases"
rg -q 'movcond_i32' "$log" \
    || die "expected movcond path for logical -> CCMP cases"
rg -q 'mov_i32 x86_raw_flags' "$log" \
    || die "expected raw-flags state update in logical path"
