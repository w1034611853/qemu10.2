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

log="${exe}.outasm.log"
host_block="${exe}.cmp_bcond_ext.block"
rm -f "$log" "$host_block"

"$qemu_bin" -d in_asm,out_asm,nochain -D "$log" "$exe" >/dev/null 2>&1 \
    || die "running $exe under $qemu_bin failed"

branch_addr=$(
awk '
BEGIN {
    in_guest = 0;
    cmp_seen = 0;
    found = 0;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    cmp_seen = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    next;
}
{
    if (in_guest) {
        if (!cmp_seen &&
            $0 ~ /^[[:space:]]*0x[0-9a-f]+:[[:space:]]+.*(subs[[:space:]]+xzr,[[:space:]]*x0,[[:space:]]*w1,[[:space:]]*uxtw|cmp[[:space:]]+x0,[[:space:]]*w1,[[:space:]]*uxtw)/) {
            cmp_seen = 1;
        } else if (cmp_seen && $0 ~ /b\.eq/) {
            if (match($0, /^0x([0-9a-f]+):/, m)) {
                print substr(m[1], length(m[1]) - 7);
                found = 1;
                exit 0;
            }
        }
    }
}
END {
    exit(found ? 0 : 1);
}
' "$log"
) || die "failed to locate ext compare-and-branch guest block"

start_line=$(grep -n -m1 "  -- guest addr .*${branch_addr}" "$log" | cut -d: -f1) \
    || die "failed to locate ext subs->b.eq host marker"

awk -v start="$start_line" '
BEGIN {
    in_range = 0;
}
NR == start {
    in_range = 1;
}
in_range {
    if (NR > start && /^  -- guest addr 0x[0-9a-f]+/) {
        exit 0;
    }
    print;
}
END {
    exit in_range ? 0 : 1;
}
' "$log" >"$host_block" || die "failed to locate ext subs->b.eq lowering segment"

if grep -Eq '(^|[^[:alnum:]_])(shr|and|xor|not|set[bcae])([^[:alnum:]_]|$)' "$host_block"; then
    die "unexpected canonical flags decode shape in ext subs->b.eq host block"
fi

grep -Eq '(^|[^[:alnum:]_])cmp[ql]([^[:alnum:]_]|$)' "$host_block" \
    || die "expected cmpq/cmpl in ext subs->b.eq lowering segment"

if ! awk '
BEGIN {
    cmp_seen = 0;
    bad = 0;
}
{
    if (!cmp_seen && $0 ~ /(^|[^[:alnum:]_])cmp[ql]([^[:alnum:]_]|$)/) {
        cmp_seen = 1;
        next;
    }
    if (cmp_seen) {
        if ($0 ~ /^  -- guest addr 0x[0-9a-f]+/) {
            exit (bad || !jcc_seen) ? 1 : 0;
        }
        if ($0 ~ /\bseto\b/) {
            next;
        }
        if ($0 ~ /\bset[a-z]+\b/ ||
            $0 ~ /\btest[qlbwd]?\b/ ||
            $0 ~ /\bcmp[ql]?\b/ ||
            $0 ~ /\bshr[qlwbd]?\b/ ||
            $0 ~ /\band[qlwbd]?\b/ ||
            $0 ~ /\bxor[qlwbd]?\b/ ||
            $0 ~ /\bnot[qlwbd]?\b/) {
            bad = 1;
        }
        for (i = 1; i <= NF; ++i) {
            if ($i ~ /^j[a-z][a-z]?$/ && $i != "jmp") {
                jcc_seen = 1;
                exit bad ? 1 : 0;
            }
        }
    }
}
END { exit (cmp_seen && jcc_seen && !bad) ? 0 : 1 }
' "$host_block"; then
    die "expected conditional jump in ext subs->b.eq lowering segment"
fi
