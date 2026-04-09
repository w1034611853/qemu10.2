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

log="${exe}.shared_raw_ccop.log"
nm_log="${exe}.shared_raw_ccop.nm"
block_dir="${exe}.shared_raw_ccop.blocks"
rm -f "$log" "$nm_log"
rm -rf "$block_dir"
mkdir -p "$block_dir"

"$qemu_bin" -cpu max -d op,nochain -D "$log" "$exe" >/dev/null 2>&1 \
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

extract_symbol_blocks()
{
    local sym=$1
    local addr
    local out

    addr=$(sym_addr "$sym")
    out="${block_dir}/${sym}.op"

    awk -v addr="$addr" '
    BEGIN {
        capture = 0;
        found = 0;
        pat = "^ ---- 0*" addr "([[:space:]]|$)";
    }
    $0 ~ pat {
        if (capture) {
            print "";
        }
        capture = 1;
        found = 1;
        print;
        next;
    }
    capture && /^ ---- [0-9a-f]+ / {
        print "";
        capture = 0;
    }
    capture {
        print;
    }
    END {
        exit(found ? 0 : 1);
    }
    ' "$log" >"$out" || die "failed to extract OP blocks for $sym"

    echo "$out"
}

assert_shared_raw_consumer_specialized()
{
    local sym=$1
    local block

    block=$(extract_symbol_blocks "$sym")

    rg -q 'x86_raw_flags' "$block" \
        || die "expected RAW-entry translation for $sym"

    if rg -q 'setcond_i32 .*x86_cc_op' "$block"; then
        die "unexpected runtime x86_cc_op dispatch remains in $sym"
    fi
}

assert_shared_raw_consumer_specialized shared_nzcv_consumer
assert_shared_raw_consumer_specialized shared_adc_consumer
assert_shared_raw_consumer_specialized shared_sbc_consumer
