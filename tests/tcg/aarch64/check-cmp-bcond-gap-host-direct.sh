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

log="${exe}.cmp_bcond_gap.outasm.log"
nm_log="${exe}.cmp_bcond_gap.nm"
block_dir="${exe}.cmp_bcond_gap.blocks"
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
    local branch_sym=$2
    local branch_addr
    local start_line
    local block

    branch_addr=$(sym_addr "$branch_sym")
    block="${block_dir}/${label}.host"
    start_line=$(rg -n -m1 "^[[:space:]]*-- guest addr 0x0*${branch_addr}([[:space:]]|$)" \
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
    assert_direct_host_block "$label" "$branch_sym"
}

assert_direct_positive "cmp gap1" cmp_gap1_producer cmp_gap1_branch 2
assert_direct_positive "subs gap4" subs_gap4_producer subs_gap4_branch 5
assert_direct_positive "cmp gap8" cmp_gap8_producer cmp_gap8_branch 9
assert_direct_positive "cmn gap1" cmn_gap1_producer cmn_gap1_branch 2
assert_direct_positive "adds gap4" adds_gap4_producer adds_gap4_branch 5
assert_direct_positive "cmn gap8" cmn_gap8_producer cmn_gap8_branch 9
assert_direct_positive "cmn vs gap1" cmn_vs_gap1_producer cmn_vs_gap1_branch 2
assert_direct_positive "adds vc gap4" adds_vc_gap4_producer adds_vc_gap4_branch 5
assert_direct_positive "cmn mi gap4" cmn_mi_gap4_producer cmn_mi_gap4_branch 5
assert_direct_positive "adds pl gap1" adds_pl_gap1_producer adds_pl_gap1_branch 2
assert_direct_positive "adcs eq gap1" adcs_eq_gap1_producer adcs_eq_gap1_branch 2
assert_direct_positive "adcs vs gap4" adcs_vs_gap4_producer adcs_vs_gap4_branch 5
assert_direct_positive "adcs rd eq gap1" adcs_rd_eq_gap1_producer adcs_rd_eq_gap1_branch 2
assert_direct_positive "adcs rd vs gap4" adcs_rd_vs_gap4_producer adcs_rd_vs_gap4_branch 5
assert_direct_positive "sbcs rd cs gap1" sbcs_rd_cs_gap1_producer sbcs_rd_cs_gap1_branch 2
assert_direct_positive "sbcs rd mi gap4" sbcs_rd_mi_gap4_producer sbcs_rd_mi_gap4_branch 5

assert_no_use "non-whitelist gap" cmp_bad_gap_producer
assert_no_use "flags writer gap" cmp_flags_writer_producer
assert_no_use "gap overflow" cmp_gap9_producer
assert_no_use "page boundary" cmp_page_boundary_producer
assert_no_use "direct control-flow cut" cmp_direct_cut_producer

assert_record "adjacent precedence" cmp_adjacent_precedence_producer
assert_use "adjacent precedence" cmp_adjacent_precedence_producer \
    cmp_adjacent_precedence_branch 1
assert_direct_host_block "adjacent precedence" cmp_adjacent_precedence_branch

rg -q 'A64 cmp-pending record pc=0x' "$log" \
    || die "expected at least one cmp-pending record marker"
rg -q 'A64 cmp-pending use producer_pc=0x' "$log" \
    || die "expected at least one cmp-pending use marker"
rg -q 'A64 cmp-pending summary tb_pc=0x' "$log" \
    || die "expected at least one cmp-pending summary marker"
