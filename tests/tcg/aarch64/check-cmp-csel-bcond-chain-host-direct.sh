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

log="${exe}.cmp_csel_bcond_chain.outasm.log"
nm_log="${exe}.cmp_csel_bcond_chain.nm"
block_dir="${exe}.cmp_csel_bcond_chain.blocks"
rm -f "$log" "$nm_log"
rm -rf "$block_dir"
mkdir -p "$block_dir"

"$qemu_bin" -d op,in_asm,out_asm,nochain -D "$log" "$exe" >/dev/null 2>&1 \
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

extract_host_block()
{
    local label=$1
    local guest_sym=$2
    local guest_addr
    local start_line
    local block

    guest_addr=$(sym_addr "$guest_sym")
    block="${block_dir}/${label}.host"
    start_line=$(rg -n -m1 "^[[:space:]]*-- guest addr 0x0*${guest_addr}([[:space:]]|$)" \
        "$log" | cut -d: -f1) || die "failed to locate host block for $label"

    awk -v start="$start_line" '
    NR >= start {
        if (NR > start &&
            (/^[[:space:]]*-- guest addr 0x[0-9a-f]+/ ||
             /^[[:space:]]*-- tb slow paths/)) {
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

assert_no_use()
{
    local label=$1
    local producer_sym=$2
    local producer_addr

    producer_addr=$(sym_addr "$producer_sym")
    if rg -q "A64 cmp-pending use producer_pc=0x${producer_addr}\\b" "$log"; then
        die "unexpected cmp-pending use for $label"
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

assert_direct_host_block()
{
    local label=$1
    local branch_sym=$2
    local block

    block=$(extract_host_block "$label" "$branch_sym")

    grep -Eq '(^|[^[:alnum:]_])(cmp[ql]|add[ql]|sub[ql]|adc[ql]|sbb[ql])([^[:alnum:]_]|$)' "$block" \
        || die "expected compare/add/sub/adc/sbb lowering in $label host block"

    if grep -Eo '\bset[a-z]+\b' "$block" | grep -Ev '^seto$' >/dev/null; then
        die "unexpected canonical flag decode setcc in $label host block"
    fi

    if grep -Eq '\b(test[qlbwd]?|shr[qlbwd]?|and[qlbwd]?|not[qlbwd]?)\b' \
        "$block"; then
        die "unexpected canonical flag decode ops in $label host block"
    fi

    awk '
    {
        for (i = 1; i <= NF; ++i) {
            if ($i ~ /^j[a-z][a-z]?$/ && $i != "jmp") {
                found = 1;
                exit 0;
            }
        }
    }
    END { exit(found ? 0 : 1) }
    ' "$block" || die "expected conditional jump in $label host block"
}

assert_chain_positive()
{
    local label=$1
    local producer_sym=$2
    local csel_sym=$3
    local branch_sym=$4

    assert_record "$label old producer" "$producer_sym"
    assert_use "$label old producer" "$producer_sym" "$csel_sym" 2 "CSEL-pending"
    assert_retire "$label old producer" "$producer_sym" "$csel_sym" 2 "CSEL-pending"

    assert_record "$label reseeded producer" "$csel_sym"
    assert_use "$label reseeded producer" "$csel_sym" "$branch_sym" 1 "B\\.cond-x86-(tcg|jcc)"
    assert_direct_host_block "$label" "$branch_sym"
}

assert_chain_gap_drop()
{
    local label=$1
    local producer_sym=$2
    local csel_sym=$3

    assert_no_record "$label old producer" "$producer_sym"
    assert_no_use "$label old producer" "$producer_sym"
    assert_no_record "$label reseeded producer" "$csel_sym"
}

assert_chain_positive \
    "cmp csel eq -> b.eq" \
    cmp_csel_eq_bcond_eq_chain_producer \
    cmp_csel_eq_bcond_eq_chain_csel \
    cmp_csel_eq_bcond_eq_chain_branch

assert_chain_positive \
    "cmp32 cset ne -> b.ne" \
    cmp32_cset_ne_bcond_ne_chain_producer \
    cmp32_cset_ne_bcond_ne_chain_csel \
    cmp32_cset_ne_bcond_ne_chain_branch

assert_chain_positive \
    "cmp csinc hi -> b.hi" \
    cmp_csinc_hi_bcond_hi_chain_producer \
    cmp_csinc_hi_bcond_hi_chain_csel \
    cmp_csinc_hi_bcond_hi_chain_branch

assert_chain_gap_drop \
    "cmp csel eq gap -> b.eq fallback" \
    cmp_csel_eq_bcond_eq_gap_producer \
    cmp_csel_eq_bcond_eq_gap_csel

rg -q 'A64 cmp-pending summary tb_pc=0x' "$log" \
    || die "expected at least one cmp-pending summary marker"
