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

log="${exe}.logic_csel.log"
nm_log="${exe}.logic_csel.nm"
block_dir="${exe}.logic_csel.blocks"
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

assert_case_contains "tst csel eq adjacent" tst_csel_eq_adj_consumer 'x86_cmov_i64'
assert_case_lacks "tst csel eq adjacent" tst_csel_eq_adj_consumer 'x86_raw_flags'
assert_case_lacks "tst csel eq adjacent" tst_csel_eq_adj_consumer 'movcond_i64'

assert_case_contains "tst csel eq adjacent rd==rn" tst_csel_eq_adj_rd_rn_consumer 'x86_cmov_i64'
assert_case_lacks "tst csel eq adjacent rd==rn" tst_csel_eq_adj_rd_rn_consumer 'x86_raw_flags'
assert_case_lacks "tst csel eq adjacent rd==rn" tst_csel_eq_adj_rd_rn_consumer 'movcond_i64'

assert_case_contains "ands csinv mi adjacent" ands_csinv_mi_adj_consumer 'x86_cmov_i64'
assert_case_contains "ands csinv mi adjacent" ands_csinv_mi_adj_consumer 'not_i64'
assert_case_lacks "ands csinv mi adjacent" ands_csinv_mi_adj_consumer 'x86_raw_flags'
assert_case_lacks "ands csinv mi adjacent" ands_csinv_mi_adj_consumer 'movcond_i64'

assert_case_contains "tst cset eq adjacent" tst_cset_eq_adj_consumer 'x86_cmov_i64'
assert_case_lacks "tst cset eq adjacent" tst_cset_eq_adj_consumer 'x86_raw_flags'
assert_case_lacks "tst cset eq adjacent" tst_cset_eq_adj_consumer 'movcond_i64'

assert_case_contains "tst cset eq false adjacent" tst_cset_eq_false_adj_consumer 'x86_cmov_i64'
assert_case_lacks "tst cset eq false adjacent" tst_cset_eq_false_adj_consumer 'x86_raw_flags'
assert_case_lacks "tst cset eq false adjacent" tst_cset_eq_false_adj_consumer 'movcond_i64'

assert_case_contains "tst csetm eq adjacent" tst_csetm_eq_adj_consumer 'x86_cmov_i64'
assert_case_lacks "tst csetm eq adjacent" tst_csetm_eq_adj_consumer 'x86_raw_flags'
assert_case_lacks "tst csetm eq adjacent" tst_csetm_eq_adj_consumer 'movcond_i64'

assert_case_contains "tst csetm eq false adjacent" tst_csetm_eq_false_adj_consumer 'x86_cmov_i64'
assert_case_lacks "tst csetm eq false adjacent" tst_csetm_eq_false_adj_consumer 'x86_raw_flags'
assert_case_lacks "tst csetm eq false adjacent" tst_csetm_eq_false_adj_consumer 'movcond_i64'

assert_case_lacks "tst csel cc adjacent" tst_csel_cc_adj_consumer 'x86_cmov_i64'
assert_case_lacks "tst csel cc adjacent" tst_csel_cc_adj_consumer 'x86_raw_flags'
assert_case_lacks "tst csel cc adjacent" tst_csel_cc_adj_consumer 'movcond_i64'

assert_case_contains "tst csel eq gap" tst_csel_eq_gap_consumer \
    'and_i32 .*x86_raw_flags,\$0x4000'
assert_case_contains "tst csel eq gap" tst_csel_eq_gap_consumer 'movcond_i64'
assert_case_lacks "tst csel eq gap" tst_csel_eq_gap_consumer 'x86_cmov_i64'

assert_case_contains "tst csel eq adjacent rm==zr false" tst_csel_eq_adj_rm_zr_false_consumer 'x86_cmov_i64'
assert_case_lacks "tst csel eq adjacent rm==zr false" tst_csel_eq_adj_rm_zr_false_consumer 'x86_raw_flags'
assert_case_lacks "tst csel eq adjacent rm==zr false" tst_csel_eq_adj_rm_zr_false_consumer 'movcond_i64'

assert_case_contains "tst csel eq adjacent rn==zr false" tst_csel_eq_adj_rn_zr_false_consumer 'x86_cmov_i64'
assert_case_lacks "tst csel eq adjacent rn==zr false" tst_csel_eq_adj_rn_zr_false_consumer 'x86_raw_flags'
assert_case_lacks "tst csel eq adjacent rn==zr false" tst_csel_eq_adj_rn_zr_false_consumer 'movcond_i64'

assert_case_contains "tst csinc adjacent" tst_csinc_adj_consumer 'x86_add_noflags_i64'
assert_case_contains "tst csinc adjacent" tst_csinc_adj_consumer 'x86_cmov_i64'
assert_case_lacks "tst csinc adjacent" tst_csinc_adj_consumer 'x86_raw_flags'
assert_case_lacks "tst csinc adjacent" tst_csinc_adj_consumer 'movcond_i64'

assert_case_contains "tst csinc adjacent rd==rn" tst_csinc_adj_rd_rn_consumer 'x86_add_noflags_i64'
assert_case_contains "tst csinc adjacent rd==rn" tst_csinc_adj_rd_rn_consumer 'x86_cmov_i64'
assert_case_lacks "tst csinc adjacent rd==rn" tst_csinc_adj_rd_rn_consumer 'x86_raw_flags'
assert_case_lacks "tst csinc adjacent rd==rn" tst_csinc_adj_rd_rn_consumer 'movcond_i64'

assert_case_contains "tst csneg adjacent" tst_csneg_adj_consumer 'not_i64'
assert_case_contains "tst csneg adjacent" tst_csneg_adj_consumer 'x86_add_noflags_i64'
assert_case_contains "tst csneg adjacent" tst_csneg_adj_consumer 'x86_cmov_i64'
assert_case_lacks "tst csneg adjacent" tst_csneg_adj_consumer 'x86_raw_flags'
assert_case_lacks "tst csneg adjacent" tst_csneg_adj_consumer 'movcond_i64'
