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
rm -f "$log" "$nm_log"

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

assert_no_direct()
{
    local label=$1
    local producer_sym=$2
    local producer_addr

    producer_addr=$(sym_addr "$producer_sym")
    if rg -q "A64 cmp-pending record pc=0x${producer_addr}\\b" "$log"; then
        die "unexpected cmp-pending record for $label"
    fi

    if rg -q "A64 cmp-pending (use|peek) producer_pc=0x${producer_addr}\\b" "$log"; then
        die "unexpected cmp-pending direct consume for $label"
    fi
}

assert_no_direct "cmp csel eq gap1" cmp_csel_eq_gap1_producer
assert_no_direct "cmp csel lt gap4" cmp_csel_lt_gap4_producer
assert_no_direct "cmp csel hi gap8" cmp_csel_hi_gap8_producer
assert_no_direct "cmp csinc eq gap1" cmp_csinc_eq_gap1_producer
assert_no_direct "cmp csinv eq gap4" cmp_csinv_eq_gap4_producer
assert_no_direct "cmp csneg eq gap8" cmp_csneg_eq_gap8_producer
assert_no_direct "cmp cset eq gap1" cmp_cset_eq_gap1_producer
assert_no_direct "cmp csetm hi gap4" cmp_csetm_hi_gap4_producer
assert_no_direct "cmp csel bad gap" cmp_csel_bad_gap_producer

if rg -q "via=CSEL-pending" "$log"; then
    die "unexpected compare-like CSEL pending-peek path still active"
fi

rg -q 'A64 cmp-pending summary tb_pc=0x' "$log" \
    || die "expected at least one cmp-pending summary marker"
