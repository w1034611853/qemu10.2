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

log="${exe}.cmp_csel_ccmp_chain.log"
nm_log="${exe}.cmp_csel_ccmp_chain.nm"
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

assert_chain_positive()
{
    local label=$1
    local producer_sym=$2
    local csel_sym=$3
    local ccmp_sym=$4

    assert_record "$label old producer" "$producer_sym"
    assert_use "$label old producer" "$producer_sym" "$csel_sym" 2 "CSEL-pending"
    assert_retire "$label old producer" "$producer_sym" "$csel_sym" 2 "CSEL-pending"

    assert_record "$label reseeded producer" "$csel_sym"
    assert_no_use "$label reseeded producer" "$csel_sym"
}

assert_chain_gap_no_reseed()
{
    local label=$1
    local producer_sym=$2
    local csel_sym=$3

    assert_record "$label old producer" "$producer_sym"
    assert_use "$label old producer" "$producer_sym" "$csel_sym" 2 "CSEL-pending"
    assert_retire "$label old producer" "$producer_sym" "$csel_sym" 2 "CSEL-pending"
    assert_no_record "$label reseeded producer" "$csel_sym"
}

assert_chain_positive \
    "cmp csel eq -> ccmp eq" \
    cmp_csel_eq_ccmp_eq_chain_producer \
    cmp_csel_eq_ccmp_eq_chain_csel \
    cmp_csel_eq_ccmp_eq_chain_ccmp

assert_chain_positive \
    "cmp32 cset ne -> ccmp ne" \
    cmp32_cset_ne_ccmp_ne_chain_producer \
    cmp32_cset_ne_ccmp_ne_chain_csel \
    cmp32_cset_ne_ccmp_ne_chain_ccmp

assert_chain_positive \
    "cmp csinc hi -> ccmn hi" \
    cmp_csinc_hi_ccmn_hi_chain_producer \
    cmp_csinc_hi_ccmn_hi_chain_csel \
    cmp_csinc_hi_ccmn_hi_chain_ccmp

assert_chain_gap_no_reseed \
    "cmp csel eq gap -> ccmp eq fallback" \
    cmp_csel_eq_ccmp_eq_gap_producer \
    cmp_csel_eq_ccmp_eq_gap_csel

rg -q 'A64 cmp-pending summary tb_pc=0x' "$log" \
    || die "expected at least one cmp-pending summary marker"
