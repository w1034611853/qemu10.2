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

log="${exe}.subs_rd_csel_gap.log"
nm_log="${exe}.subs_rd_csel_gap.nm"
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

assert_record()
{
    local label=$1
    local producer_sym=$2
    local producer_addr

    producer_addr=$(sym_addr "$producer_sym")
    rg -q "A64 cmp-pending record pc=0x${producer_addr}\\b" "$log" \
        || die "expected cmp-pending record for $label"
}

assert_peek()
{
    local label=$1
    local producer_sym=$2
    local consumer_sym=$3
    local age=$4
    local producer_addr
    local consumer_addr

    producer_addr=$(sym_addr "$producer_sym")
    consumer_addr=$(sym_addr "$consumer_sym")
    rg -q "A64 cmp-pending peek producer_pc=0x${producer_addr} consumer_pc=0x${consumer_addr} age=${age} via=CSEL-pending" \
        "$log" || die "expected cmp-pending peek for $label"
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

assert_record "subs rd csel eq gap1" subs_rd_csel_eq_gap1_producer
assert_peek "subs rd csel eq gap1" \
    subs_rd_csel_eq_gap1_producer subs_rd_csel_eq_gap1_consumer 2

assert_record "subs rd csel lt gap4" subs_rd_csel_lt_gap4_producer
assert_peek "subs rd csel lt gap4" \
    subs_rd_csel_lt_gap4_producer subs_rd_csel_lt_gap4_consumer 5

assert_record "subs rd csinc eq gap1" subs_rd_csinc_eq_gap1_producer
assert_peek "subs rd csinc eq gap1" \
    subs_rd_csinc_eq_gap1_producer subs_rd_csinc_eq_gap1_consumer 2

assert_record "subs rd csinv eq gap4" subs_rd_csinv_eq_gap4_producer
assert_peek "subs rd csinv eq gap4" \
    subs_rd_csinv_eq_gap4_producer subs_rd_csinv_eq_gap4_consumer 5

assert_record "subs rd csneg eq gap8" subs_rd_csneg_eq_gap8_producer
assert_peek "subs rd csneg eq gap8" \
    subs_rd_csneg_eq_gap8_producer subs_rd_csneg_eq_gap8_consumer 9

assert_record "subs rd cset eq gap1" subs_rd_cset_eq_gap1_producer
assert_peek "subs rd cset eq gap1" \
    subs_rd_cset_eq_gap1_producer subs_rd_cset_eq_gap1_consumer 2

assert_record "subs rd csetm hi gap4" subs_rd_csetm_hi_gap4_producer
assert_peek "subs rd csetm hi gap4" \
    subs_rd_csetm_hi_gap4_producer subs_rd_csetm_hi_gap4_consumer 5

assert_no_record "subs rd csel bad gap" subs_rd_csel_bad_gap_producer
assert_no_use "subs rd csel bad gap" subs_rd_csel_bad_gap_producer

rg -q 'A64 cmp-pending summary tb_pc=0x' "$log" \
    || die "expected at least one cmp-pending summary marker"
