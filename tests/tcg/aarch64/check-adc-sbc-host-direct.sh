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
cmn_adc_block="${exe}.cmn_adc.block"
cmn_adc32_block="${exe}.cmn_adc32.block"
adds_adc_block="${exe}.adds_adc.block"
adds_adc32_block="${exe}.adds_adc32.block"
subs_sbc_block="${exe}.subs_sbc.block"
subs_sbc32_block="${exe}.subs_sbc32.block"
cmp_sbc_block="${exe}.cmp_sbc.block"
cmn_adc_imm_block="${exe}.cmn_adc_imm.block"
adds_adc_imm_block="${exe}.adds_adc_imm.block"
adds_adc32_imm_block="${exe}.adds_adc32_imm.block"
subs_sbc_imm_block="${exe}.subs_sbc_imm.block"
subs_sbc32_imm_block="${exe}.subs_sbc32_imm.block"
cmp_sbc_imm_block="${exe}.cmp_sbc_imm.block"
cmp_sbc32_imm_block="${exe}.cmp_sbc32_imm.block"
cmn_adc_ext_block="${exe}.cmn_adc_ext.block"
cmn_adc32_ext_block="${exe}.cmn_adc32_ext.block"
adds_adc_ext_block="${exe}.adds_adc_ext.block"
adds_adc32_ext_block="${exe}.adds_adc32_ext.block"
subs_sbc_ext_block="${exe}.subs_sbc_ext.block"
subs_sbc32_ext_block="${exe}.subs_sbc32_ext.block"
cmp_sbc_ext_block="${exe}.cmp_sbc_ext.block"
cmp_sbc32_ext_block="${exe}.cmp_sbc32_ext.block"
cmn_adcs_block="${exe}.cmn_adcs.block"
cmp_sbcs_block="${exe}.cmp_sbcs.block"
adds_adcs_block="${exe}.adds_adcs.block"
adds_adcs32_block="${exe}.adds_adcs32.block"
subs_sbcs_block="${exe}.subs_sbcs.block"
subs_sbcs32_block="${exe}.subs_sbcs32.block"
adcs_adc_block="${exe}.adcs_adc.block"
adcs_adc32_block="${exe}.adcs_adc32.block"
sbcs_sbc_block="${exe}.sbcs_sbc.block"
sbcs_sbc32_block="${exe}.sbcs_sbc32.block"
adcs32_adc64_block="${exe}.adcs32_adc64.block"
rm -f "$log"
rm -f "$cmn_adc_block"
rm -f "$cmn_adc32_block"
rm -f "$adds_adc_block"
rm -f "$adds_adc32_block"
rm -f "$subs_sbc_block"
rm -f "$subs_sbc32_block"
rm -f "$cmp_sbc_block"
rm -f "$cmn_adc_imm_block"
rm -f "$adds_adc_imm_block"
rm -f "$adds_adc32_imm_block"
rm -f "$subs_sbc_imm_block"
rm -f "$subs_sbc32_imm_block"
rm -f "$cmp_sbc_imm_block"
rm -f "$cmp_sbc32_imm_block"
rm -f "$cmn_adc_ext_block"
rm -f "$cmn_adc32_ext_block"
rm -f "$adds_adc_ext_block"
rm -f "$adds_adc32_ext_block"
rm -f "$subs_sbc_ext_block"
rm -f "$subs_sbc32_ext_block"
rm -f "$cmp_sbc_ext_block"
rm -f "$cmp_sbc32_ext_block"
rm -f "$cmn_adcs_block"
rm -f "$cmp_sbcs_block"
rm -f "$adds_adcs_block"
rm -f "$adds_adcs32_block"
rm -f "$subs_sbcs_block"
rm -f "$subs_sbcs32_block"
rm -f "$adcs_adc_block"
rm -f "$adcs_adc32_block"
rm -f "$sbcs_sbc_block"
rm -f "$sbcs_sbc32_block"
rm -f "$adcs32_adc64_block"

compare_like_ext_decode_re='\bshr[lq]\b|\band[lq]\b|\bxor[lq]\b|\bnot[lq]\b|\bset[bcae]\b'

"$qemu_bin" -d in_asm,out_asm,nochain -D "$log" "$exe" >/dev/null 2>&1 \
    || die "running $exe under $qemu_bin failed"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    adds = 0;
    adcs = 0;
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    adds = 0;
    adcs = 0;
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    guest_line = 0;
    adds = 0;
    adcs = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (guest ~ /cmp[[:space:]]+x5, x5/ &&
        guest ~ /sbc[[:space:]]+x8, x5, x6/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$cmp_sbc_block" || die "failed to locate adjacent cmp->sbc host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    subs = 0;
    sbcs = 0;
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    subs = 0;
    sbcs = 0;
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    guest_line = 0;
    subs = 0;
    sbcs = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (guest ~ /cmn[[:space:]]+x0, x1/ &&
        guest ~ /adc[[:space:]]+x7, x5, x6/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$cmn_adc_block" || die "failed to locate adjacent cmn->adc host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    adds = 0;
    adcs = 0;
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    adds = 0;
    adcs = 0;
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    guest_line = 0;
    adds = 0;
    adcs = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (guest ~ /cmn[[:space:]]+w0, w1/ &&
        guest ~ /adc[[:space:]]+w7, w5, w6/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$cmn_adc32_block" || die "failed to locate adjacent cmn->adc32 host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    subs = 0;
    sbcs = 0;
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    subs = 0;
    sbcs = 0;
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    guest_line = 0;
    subs = 0;
    sbcs = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (guest ~ /adds[[:space:]]+x5, x0, x1/ &&
        guest ~ /adc[[:space:]]+x8, x6, x7/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$adds_adc_block" || die "failed to locate adjacent adds-rd->adc host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (guest ~ /adds[[:space:]]+w5, w0, w1/ &&
        guest ~ /adc[[:space:]]+w8, w6, w7/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$adds_adc32_block" || die "failed to locate adjacent adds-rd->adc32 host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (guest ~ /subs[[:space:]]+x5, x0, x1/ &&
        guest ~ /sbc[[:space:]]+x8, x6, x7/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$subs_sbc_block" || die "failed to locate adjacent subs-rd->sbc host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (guest ~ /subs[[:space:]]+w5, w0, w1/ &&
        guest ~ /sbc[[:space:]]+w8, w6, w7/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$subs_sbc32_block" || die "failed to locate adjacent subs-rd->sbc32 host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (guest ~ /cmn[[:space:]]+x0, #(0x)?1/ &&
        guest ~ /adc[[:space:]]+x11, x9, x10/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$cmn_adc_imm_block" || die "failed to locate adjacent cmn-imm->adc host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (guest ~ /adds[[:space:]]+x13, x0, #(0x)?1/ &&
        guest ~ /adc[[:space:]]+x14, x9, x10/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$adds_adc_imm_block" || die "failed to locate adjacent adds-imm->adc host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (guest ~ /adds[[:space:]]+w13, w0, #(0x)?1/ &&
        guest ~ /adc[[:space:]]+w14, w9, w10/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$adds_adc32_imm_block" || die "failed to locate adjacent adds-imm->adc32 host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (guest ~ /subs[[:space:]]+x15, x0, #(0x)?1/ &&
        guest ~ /sbc[[:space:]]+x16, x9, x10/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$subs_sbc_imm_block" || die "failed to locate adjacent subs-imm->sbc host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (guest ~ /subs[[:space:]]+w15, w0, #(0x)?1/ &&
        guest ~ /sbc[[:space:]]+w16, w9, w10/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$subs_sbc32_imm_block" || die "failed to locate adjacent subs-imm->sbc32 host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (guest ~ /cmp[[:space:]]+x9, #(0x)?9/ &&
        guest ~ /sbc[[:space:]]+x12, x9, x10/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$cmp_sbc_imm_block" || die "failed to locate adjacent cmp-imm->sbc host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (guest ~ /cmp[[:space:]]+w9, #(0x)?9/ &&
        guest ~ /sbc[[:space:]]+w12, w9, w10/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$cmp_sbc32_imm_block" || die "failed to locate adjacent cmp-imm->sbc32 host block"

grep -Eq '\baddq\b|\baddl\b' "$cmn_adc_block" \
    || die "missing host add for adjacent CMN->ADC path"
grep -Eq '\badcq?\b|\badcl\b' "$cmn_adc_block" \
    || die "missing host adc for adjacent CMN->ADC path"
if grep -Eq '\bshr[lq]\b' "$cmn_adc_block"; then
    die "adjacent CMN->ADC still decodes carry from canonical flags"
fi
if grep -Eq '\band[lq]\b' "$cmn_adc_block"; then
    die "adjacent CMN->ADC still masks decoded carry bits"
fi
if grep -Eq '\bset[bcae]\b' "$cmn_adc_block"; then
    die "adjacent CMN->ADC still rebuilds carry via setcc"
fi
grep -Eq '\baddl\b' "$cmn_adc32_block" \
    || die "missing host addl for adjacent CMN->ADC32 path"
grep -Eq '\badcl\b' "$cmn_adc32_block" \
    || die "missing host adcl for adjacent CMN->ADC32 path"
awk '
/addl/ {
    in_pair = 1;
    next;
}
in_pair && /adcl/ {
    exit bad;
}
in_pair && /\bpushq\b|\bpopq\b/ {
    bad = 1;
}
END {
    exit bad;
}
' "$cmn_adc32_block" || die "adjacent CMN->ADC32 still saves rawflags via push/pop between addl and adcl"
grep -Eq '\baddq\b|\baddl\b' "$adds_adc_block" \
    || die "missing host add for adjacent ADDS->ADC path"
grep -Eq '\badcq?\b|\badcl\b' "$adds_adc_block" \
    || die "missing host adc for adjacent ADDS->ADC path"
if grep -Eq '\bshr[lq]\b|\band[lq]\b|\bset[bcae]\b' "$adds_adc_block"; then
    die "adjacent ADDS->ADC still decodes carry before consumer adc"
fi
grep -Eq '\baddl\b' "$adds_adc32_block" \
    || die "missing host addl for adjacent ADDS32->ADC32 path"
grep -Eq '\badcl\b' "$adds_adc32_block" \
    || die "missing host adcl for adjacent ADDS32->ADC32 path"
if grep -Eq '\bshr[lq]\b|\band[lq]\b|\bset[bcae]\b' "$adds_adc32_block"; then
    die "adjacent ADDS32->ADC32 still decodes carry before consumer adc"
fi

grep -Eq '\bsubq\b' "$subs_sbc_block" \
    || die "missing host subq for adjacent SUBS->SBC path"
grep -Eq '\bsbbq\b' "$subs_sbc_block" \
    || die "missing host sbbq for adjacent SUBS->SBC path"
awk '
/subq/ && !seen_sub {
    seen_sub = 1;
    sub_count = 1;
    next;
}
seen_sub && !seen_sbb && /subq/ {
    sub_count++;
}
seen_sub && !seen_sbb && /sbbq/ {
    seen_sbb = 1;
    exit (bad || sub_count != 1) ? 1 : 0;
}
seen_sub && !seen_sbb &&
(/\bshr[lq]\b/ || /\band[lq]\b/ || /\bset[bcae]\b/ || /\bcmpq\b|\bcmpl\b/) {
    bad = 1;
}
END {
    if (!seen_sub || !seen_sbb || bad || sub_count != 1) {
        exit 1;
    }
}
' "$subs_sbc_block" || die "adjacent SUBS->SBC still decodes borrow before consumer sbb"

grep -Eq '\bsubl\b' "$subs_sbc32_block" \
    || die "missing host subl for adjacent SUBS32->SBC32 path"
grep -Eq '\bsbbl\b' "$subs_sbc32_block" \
    || die "missing host sbbl for adjacent SUBS32->SBC32 path"
awk '
/subl/ && !seen_sub {
    seen_sub = 1;
    sub_count = 1;
    next;
}
seen_sub && !seen_sbb && /subl/ {
    sub_count++;
}
seen_sub && !seen_sbb && /sbbl/ {
    seen_sbb = 1;
    exit (bad || sub_count != 1) ? 1 : 0;
}
seen_sub && !seen_sbb &&
(/\bshrl\b/ || /\bandl\b/ || /\bset[bcae]\b/ || /\bcmpl\b|\bcmpq\b/) {
    bad = 1;
}
END {
    if (!seen_sub || !seen_sbb || bad || sub_count != 1) {
        exit 1;
    }
}
' "$subs_sbc32_block" || die "adjacent SUBS32->SBC32 still decodes borrow before consumer sbb"

grep -Eq '\bcmpq\b|\bcmpl\b' "$cmp_sbc_block" \
    || die "missing host cmp for adjacent CMP->SBC path"
grep -Eq '\bsbbq\b|\bsbbl\b' "$cmp_sbc_block" \
    || die "missing host sbb for adjacent CMP->SBC path"
if grep -Eq '\bshr[lq]\b' "$cmp_sbc_block"; then
    die "adjacent CMP->SBC still decodes carry from canonical flags"
fi
if grep -Eq '\bxor[lq]\b[[:space:]]+\\$0x?1|\bxor[lq]\b[[:space:]]+\\$1' "$cmp_sbc_block"; then
    die "adjacent CMP->SBC still flips carry via decode path"
fi
if grep -Eq '\bsub[lq]\b' "$cmp_sbc_block"; then
    die "adjacent CMP->SBC still seeds borrow via extra sub"
fi

grep -Eq '\baddq\b|\baddl\b' "$cmn_adc_imm_block" \
    || die "missing host add for adjacent CMN-imm->ADC path"
grep -Eq '\badcq?\b|\badcl\b' "$cmn_adc_imm_block" \
    || die "missing host adc for adjacent CMN-imm->ADC path"
if grep -Eq '\bshr[lq]\b|\band[lq]\b|\bset[bcae]\b' "$cmn_adc_imm_block"; then
    die "adjacent CMN-imm->ADC still decodes carry before consumer adc"
fi

grep -Eq '\baddq\b|\baddl\b' "$adds_adc_imm_block" \
    || die "missing host add for adjacent ADDS-imm->ADC path"
grep -Eq '\badcq?\b|\badcl\b' "$adds_adc_imm_block" \
    || die "missing host adc for adjacent ADDS-imm->ADC path"
if grep -Eq '\bshr[lq]\b|\band[lq]\b|\bset[bcae]\b' "$adds_adc_imm_block"; then
    die "adjacent ADDS-imm->ADC still decodes carry before consumer adc"
fi

grep -Eq '\baddl\b' "$adds_adc32_imm_block" \
    || die "missing host addl for adjacent ADDS-imm->ADC32 path"
grep -Eq '\badcl\b' "$adds_adc32_imm_block" \
    || die "missing host adcl for adjacent ADDS-imm->ADC32 path"
if grep -Eq '\bshrl\b|\bandl\b|\bset[bcae]\b' "$adds_adc32_imm_block"; then
    die "adjacent ADDS-imm->ADC32 still decodes carry before consumer adc"
fi

grep -Eq '\bsubq\b' "$subs_sbc_imm_block" \
    || die "missing host subq for adjacent SUBS-imm->SBC path"
grep -Eq '\bsbbq\b' "$subs_sbc_imm_block" \
    || die "missing host sbbq for adjacent SUBS-imm->SBC path"
awk '
/subq/ && !seen_sub {
    seen_sub = 1;
    sub_count = 1;
    next;
}
seen_sub && !seen_sbb && /subq/ {
    sub_count++;
}
seen_sub && !seen_sbb && /sbbq/ {
    seen_sbb = 1;
    exit (bad || sub_count != 1) ? 1 : 0;
}
seen_sub && !seen_sbb &&
(/\bshr[lq]\b/ || /\band[lq]\b/ || /\bset[bcae]\b/ || /\bcmpq\b|\bcmpl\b/) {
    bad = 1;
}
END {
    if (!seen_sub || !seen_sbb || bad || sub_count != 1) {
        exit 1;
    }
}
' "$subs_sbc_imm_block" || die "adjacent SUBS-imm->SBC still decodes borrow before consumer sbb"

grep -Eq '\bsubl\b' "$subs_sbc32_imm_block" \
    || die "missing host subl for adjacent SUBS-imm->SBC32 path"
grep -Eq '\bsbbl\b' "$subs_sbc32_imm_block" \
    || die "missing host sbbl for adjacent SUBS-imm->SBC32 path"
awk '
/subl/ && !seen_sub {
    seen_sub = 1;
    sub_count = 1;
    next;
}
seen_sub && !seen_sbb && /subl/ {
    sub_count++;
}
seen_sub && !seen_sbb && /sbbl/ {
    seen_sbb = 1;
    exit (bad || sub_count != 1) ? 1 : 0;
}
seen_sub && !seen_sbb &&
(/\bshrl\b/ || /\bandl\b/ || /\bset[bcae]\b/ || /\bcmpl\b|\bcmpq\b/) {
    bad = 1;
}
END {
    if (!seen_sub || !seen_sbb || bad || sub_count != 1) {
        exit 1;
    }
}
' "$subs_sbc32_imm_block" || die "adjacent SUBS-imm->SBC32 still decodes borrow before consumer sbb"

grep -Eq '\bcmpq\b|\bcmpl\b' "$cmp_sbc_imm_block" \
    || die "missing host cmp for adjacent CMP-imm->SBC path"
grep -Eq '\bsbbq\b|\bsbbl\b' "$cmp_sbc_imm_block" \
    || die "missing host sbb for adjacent CMP-imm->SBC path"
if grep -Eq '\bshr[lq]\b' "$cmp_sbc_imm_block"; then
    die "adjacent CMP-imm->SBC still decodes carry from canonical flags"
fi
if grep -Eq '\bxor[lq]\b[[:space:]]+\\$0x?1|\bxor[lq]\b[[:space:]]+\\$1' "$cmp_sbc_imm_block"; then
    die "adjacent CMP-imm->SBC still flips carry via decode path"
fi
if grep -Eq '\bsub[lq]\b' "$cmp_sbc_imm_block"; then
    die "adjacent CMP-imm->SBC still seeds borrow via extra sub"
fi

grep -Eq '\bcmpq\b|\bcmpl\b' "$cmp_sbc32_imm_block" \
    || die "missing host cmp for adjacent CMP-imm->SBC32 path"
grep -Eq '\bsbbq\b|\bsbbl\b' "$cmp_sbc32_imm_block" \
    || die "missing host sbb for adjacent CMP-imm->SBC32 path"
if grep -Eq '\bshrl\b' "$cmp_sbc32_imm_block"; then
    die "adjacent CMP-imm->SBC32 still decodes carry from canonical flags"
fi
if grep -Eq '\bxorl\b[[:space:]]+\\$0x?1|\bxorl\b[[:space:]]+\\$1' "$cmp_sbc32_imm_block"; then
    die "adjacent CMP-imm->SBC32 still flips carry via decode path"
fi
if grep -Eq '\bsubl\b' "$cmp_sbc32_imm_block"; then
    die "adjacent CMP-imm->SBC32 still seeds borrow via extra sub"
fi

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = host $0 "\n";
    if (guest ~ /cmn[[:space:]]+x0, w1, uxtw/ &&
        guest ~ /adc[[:space:]]+x11, x9, x10/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$cmn_adc_ext_block" || die "failed to locate adjacent cmn-ext->adc host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = host $0 "\n";
    if (guest ~ /cmn[[:space:]]+w0, w1, uxtw/ &&
        guest ~ /adc[[:space:]]+w11, w9, w10/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$cmn_adc32_ext_block" || die "failed to locate adjacent cmn-ext->adc32 host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = host $0 "\n";
    if (guest ~ /cmp[[:space:]]+x9, w2, uxtw/ &&
        guest ~ /sbc[[:space:]]+x12, x9, x10/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$cmp_sbc_ext_block" || die "failed to locate adjacent cmp-ext->sbc host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = host $0 "\n";
    if (guest ~ /cmp[[:space:]]+w9, w2, uxtw/ &&
        guest ~ /sbc[[:space:]]+w12, w9, w10/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$cmp_sbc32_ext_block" || die "failed to locate adjacent cmp-ext->sbc32 host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = host $0 "\n";
    if (guest ~ /adds[[:space:]]+x13, x0, w1, uxtw/ &&
        guest ~ /adc[[:space:]]+x14, x9, x10/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$adds_adc_ext_block" || die "failed to locate adjacent adds-ext->adc host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = host $0 "\n";
    if (guest ~ /adds[[:space:]]+w13, w0, w1, uxtw/ &&
        guest ~ /adc[[:space:]]+w14, w9, w10/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$adds_adc32_ext_block" || die "failed to locate adjacent adds-ext->adc32 host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = host $0 "\n";
    if (guest ~ /subs[[:space:]]+x15, x0, w1, uxtw/ &&
        guest ~ /sbc[[:space:]]+x16, x9, x10/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$subs_sbc_ext_block" || die "failed to locate adjacent subs-ext->sbc host block"

awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = host $0 "\n";
    if (guest ~ /subs[[:space:]]+w15, w0, w1, uxtw/ &&
        guest ~ /sbc[[:space:]]+w16, w9, w10/) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest = guest $0 "\n";
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$subs_sbc32_ext_block" || die "failed to locate adjacent subs-ext->sbc32 host block"

# ADCS adjacent negative block extractor:
# mov x5, #9 / mov x6, #3 / cmn x0, x1 / adcs x7, x5, x6
awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    mov_x5 = 0;
    mov_x6 = 0;
    cmn = 0;
    adcs = 0;
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    mov_x5 = 0;
    mov_x6 = 0;
    cmn = 0;
    adcs = 0;
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    guest_line = 0;
    mov_x5 = 0;
    mov_x6 = 0;
    cmn = 0;
    adcs = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (mov_x5 > 0 && mov_x6 == mov_x5 + 1 &&
        cmn > mov_x6 &&
        adcs == cmn + 1) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest_line++;
        guest = guest $0 "\n";
        if ($0 ~ /x5, #0x9/) {
            mov_x5 = guest_line;
        } else if ($0 ~ /x6, #0x3/) {
            mov_x6 = guest_line;
        } else if ($0 ~ /cmn[[:space:]]+x0, x1/) {
            cmn = guest_line;
        } else if ($0 ~ /adcs[[:space:]]+x7, x5, x6/) {
            adcs = guest_line;
        }
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$cmn_adcs_block" || die "failed to locate adjacent cmn->adcs host block"

# SBCS adjacent negative block extractor:
# mov x5, #9 / mov x6, #3 / cmp x0, x1 / sbcs x7, x5, x6
awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    mov_x5 = 0;
    mov_x6 = 0;
    cmp = 0;
    sbcs = 0;
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    mov_x5 = 0;
    mov_x6 = 0;
    cmp = 0;
    sbcs = 0;
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    guest_line = 0;
    mov_x5 = 0;
    mov_x6 = 0;
    cmp = 0;
    sbcs = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (mov_x5 > 0 && mov_x6 == mov_x5 + 1 &&
        cmp > mov_x6 &&
        sbcs == cmp + 1) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest_line++;
        guest = guest $0 "\n";
        if ($0 ~ /x5, #0x9/) {
            mov_x5 = guest_line;
        } else if ($0 ~ /x6, #0x3/) {
            mov_x6 = guest_line;
        } else if ($0 ~ /cmp[[:space:]]+x0, x1/) {
            cmp = guest_line;
        } else if ($0 ~ /sbcs[[:space:]]+x7, x5, x6/) {
            sbcs = guest_line;
        }
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$cmp_sbcs_block" || die "failed to locate adjacent cmp->sbcs host block"

check_compare_like_ext_direct() {
    grep -Eq '\baddq\b' "$cmn_adc_ext_block" \
        || die "missing host addq for adjacent CMN-ext->ADC path"
    grep -Eq '\badcq\b' "$cmn_adc_ext_block" \
        || die "missing host adcq for adjacent CMN-ext->ADC path"
    if grep -Eq "$compare_like_ext_decode_re" "$cmn_adc_ext_block"; then
        die "adjacent CMN-ext->ADC still decodes carry before consumer adc"
    fi

    grep -Eq '\baddl\b' "$cmn_adc32_ext_block" \
        || die "missing host addl for adjacent CMN-ext->ADC32 path"
    grep -Eq '\badcl\b' "$cmn_adc32_ext_block" \
        || die "missing host adcl for adjacent CMN-ext->ADC32 path"
    awk '
    /addl/ && !seen_add {
        seen_add = 1;
        add_count = 1;
        next;
    }
    seen_add && !seen_adc && /addl/ {
        add_count++;
    }
    seen_add && !seen_adc && /adcl/ {
        seen_adc = 1;
        exit (bad || add_count != 1) ? 1 : 0;
    }
    seen_add && !seen_adc && /\bpushq\b|\bpopq\b/ {
        bad = 1;
    }
    seen_add && !seen_adc &&
    (/\bshrl\b/ || /\bandl\b/ || /\bxorl\b/ ||
     /\bnotl\b/ || /\bset[bcae]\b/) {
        bad = 1;
    }
    END {
        if (!seen_add || !seen_adc || bad || add_count != 1) {
            exit 1;
        }
    }
    ' "$cmn_adc32_ext_block" || \
        die "adjacent CMN-ext->ADC32 still rebuilds carry or saves rawflags between addl and adcl"

    grep -Eq '\bcmpq\b' "$cmp_sbc_ext_block" \
        || die "missing host cmpq for adjacent CMP-ext->SBC path"
    grep -Eq '\bsbbq\b' "$cmp_sbc_ext_block" \
        || die "missing host sbbq for adjacent CMP-ext->SBC path"
    if grep -Eq "$compare_like_ext_decode_re" "$cmp_sbc_ext_block"; then
        die "adjacent CMP-ext->SBC still decodes carry before consumer sbb"
    fi
    if grep -Eq '\bsubq\b' "$cmp_sbc_ext_block"; then
        die "adjacent CMP-ext->SBC still seeds borrow via extra sub"
    fi

    grep -Eq '\bcmpl\b' "$cmp_sbc32_ext_block" \
        || die "missing host cmpl for adjacent CMP-ext->SBC32 path"
    grep -Eq '\bsbbl\b' "$cmp_sbc32_ext_block" \
        || die "missing host sbbl for adjacent CMP-ext->SBC32 path"
    if grep -Eq "$compare_like_ext_decode_re" "$cmp_sbc32_ext_block"; then
        die "adjacent CMP-ext->SBC32 still decodes carry before consumer sbb"
    fi
    if grep -Eq '\bsubl\b' "$cmp_sbc32_ext_block"; then
        die "adjacent CMP-ext->SBC32 still seeds borrow via extra sub"
    fi
}

check_compare_like_ext_direct

grep -Eq '\baddq\b' "$adds_adc_ext_block" \
    || die "missing host addq for adjacent ADDS-ext->ADC path"
grep -Eq '\badcq\b' "$adds_adc_ext_block" \
    || die "missing host adcq for adjacent ADDS-ext->ADC path"
awk '
/addq/ && !seen_add {
    seen_add = 1;
    add_count = 1;
    next;
}
seen_add && !seen_adc && /addq/ {
    add_count++;
}
seen_add && !seen_adc && /adcq/ {
    seen_adc = 1;
    exit (bad || add_count != 1) ? 1 : 0;
}
seen_add && !seen_adc &&
(/\bshr[lq]\b/ || /\band[lq]\b/ || /\bxor[lq]\b/ ||
 /\bnot[lq]\b/ || /\bset[bcae]\b/) {
    bad = 1;
}
END {
    if (!seen_add || !seen_adc || bad || add_count != 1) {
        exit 1;
    }
}
' "$adds_adc_ext_block" || die "adjacent ADDS-ext->ADC still decodes carry before consumer adc"

grep -Eq '\baddl\b' "$adds_adc32_ext_block" \
    || die "missing host addl for adjacent ADDS-ext->ADC32 path"
grep -Eq '\badcl\b' "$adds_adc32_ext_block" \
    || die "missing host adcl for adjacent ADDS-ext->ADC32 path"
awk '
/addl/ && !seen_add {
    seen_add = 1;
    add_count = 1;
    next;
}
seen_add && !seen_adc && /addl/ {
    add_count++;
}
seen_add && !seen_adc && /adcl/ {
    seen_adc = 1;
    exit (bad || add_count != 1) ? 1 : 0;
}
seen_add && !seen_adc &&
(/\bshrl\b/ || /\bandl\b/ || /\bxorl\b/ ||
 /\bnotl\b/ || /\bset[bcae]\b/) {
    bad = 1;
}
END {
    if (!seen_add || !seen_adc || bad || add_count != 1) {
        exit 1;
    }
}
' "$adds_adc32_ext_block" || die "adjacent ADDS-ext->ADC32 still decodes carry before consumer adc"

grep -Eq '\bsubq\b' "$subs_sbc_ext_block" \
    || die "missing host subq for adjacent SUBS-ext->SBC path"
grep -Eq '\bsbbq\b' "$subs_sbc_ext_block" \
    || die "missing host sbbq for adjacent SUBS-ext->SBC path"
awk '
/subq/ && !seen_sub {
    seen_sub = 1;
    sub_count = 1;
    next;
}
seen_sub && !seen_sbb && /subq/ {
    sub_count++;
}
seen_sub && !seen_sbb && /sbbq/ {
    seen_sbb = 1;
    exit (bad || sub_count != 1) ? 1 : 0;
}
seen_sub && !seen_sbb &&
(/\bshr[lq]\b/ || /\band[lq]\b/ || /\bxor[lq]\b/ ||
 /\bnot[lq]\b/ || /\bset[bcae]\b/) {
    bad = 1;
}
END {
    if (!seen_sub || !seen_sbb || bad || sub_count != 1) {
        exit 1;
    }
}
' "$subs_sbc_ext_block" || die "adjacent SUBS-ext->SBC still decodes borrow before consumer sbb"

grep -Eq '\bsubl\b' "$subs_sbc32_ext_block" \
    || die "missing host subl for adjacent SUBS-ext->SBC32 path"
grep -Eq '\bsbbl\b' "$subs_sbc32_ext_block" \
    || die "missing host sbbl for adjacent SUBS-ext->SBC32 path"
awk '
/subl/ && !seen_sub {
    seen_sub = 1;
    sub_count = 1;
    next;
}
seen_sub && !seen_sbb && /subl/ {
    sub_count++;
}
seen_sub && !seen_sbb && /sbbl/ {
    seen_sbb = 1;
    exit (bad || sub_count != 1) ? 1 : 0;
}
seen_sub && !seen_sbb &&
(/\bshrl\b/ || /\bandl\b/ || /\bxorl\b/ ||
 /\bnotl\b/ || /\bset[bcae]\b/) {
    bad = 1;
}
END {
    if (!seen_sub || !seen_sbb || bad || sub_count != 1) {
        exit 1;
    }
}
' "$subs_sbc32_ext_block" || die "adjacent SUBS-ext->SBC32 still decodes borrow before consumer sbb"

# ========================================================================
# Step 3: codegen guard 分成"支持路径硬检查"和"收窄路径负向检查"两类
# ========================================================================

# ------------------------------------------------------------------------
# 3.1 对 materialized ADDS/SUBS -> ADCS/SBCS 做 direct 硬检查
# ------------------------------------------------------------------------

# ADDS reg -> ADCS: adds x5, x0, x1 / adcs x8, x6, x7 (真正相邻)
awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (adds > 0 && adcs == adds + 1) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest_line++;
        guest = guest $0 "\n";
        if ($0 ~ /adds[[:space:]]+x5, x0, x1/) {
            adds = guest_line;
        } else if ($0 ~ /adcs[[:space:]]+x8, x6, x7/) {
            adcs = guest_line;
        }
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$adds_adcs_block" || die "failed to locate adjacent ADDS->ADCS host block"

# SUBS reg -> SBCS: subs x5, x0, x1 / sbcs x8, x6, x7 (真正相邻)
awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (subs > 0 && sbcs == subs + 1) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest_line++;
        guest = guest $0 "\n";
        if ($0 ~ /subs[[:space:]]+x5, x0, x1/) {
            subs = guest_line;
        } else if ($0 ~ /sbcs[[:space:]]+x8, x6, x7/) {
            sbcs = guest_line;
        }
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$subs_sbcs_block" || die "failed to locate adjacent SUBS->SBCS host block"

# ADDS reg32 -> ADCS32: adds w5, w0, w1 / adcs w8, w6, w7 (真正相邻)
awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (adds > 0 && adcs == adds + 1) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest_line++;
        guest = guest $0 "\n";
        if ($0 ~ /adds[[:space:]]+w5, w0, w1/) {
            adds = guest_line;
        } else if ($0 ~ /adcs[[:space:]]+w8, w6, w7/) {
            adcs = guest_line;
        }
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$adds_adcs32_block" || die "failed to locate adjacent ADDS32->ADCS32 host block"

# SUBS reg32 -> SBCS32: subs w5, w0, w1 / sbcs w8, w6, w7 (真正相邻)
awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (subs > 0 && sbcs == subs + 1) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest_line++;
        guest = guest $0 "\n";
        if ($0 ~ /subs[[:space:]]+w5, w0, w1/) {
            subs = guest_line;
        } else if ($0 ~ /sbcs[[:space:]]+w8, w6, w7/) {
            sbcs = guest_line;
        }
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$subs_sbcs32_block" || die "failed to locate adjacent SUBS32->SBCS32 host block"

# ADCS reg -> ADC: adcs x5, x1, x2 / adc x8, x6, x7 (真正相邻)
awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    adcs = 0;
    adc = 0;
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    adcs = 0;
    adc = 0;
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    guest_line = 0;
    adcs = 0;
    adc = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (adcs > 0 && adc == adcs + 1) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest_line++;
        guest = guest $0 "\n";
        if ($0 ~ /adcs[[:space:]]+x5, x1, x2/) {
            adcs = guest_line;
        } else if ($0 ~ /adc[[:space:]]+x8, x6, x7/) {
            adc = guest_line;
        }
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$adcs_adc_block" || die "failed to locate adjacent ADCS->ADC host block"

# ADCS32 -> ADC32: adcs w5, w1, w2 / adc w8, w6, w7 (真正相邻)
awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    adcs = 0;
    adc = 0;
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    adcs = 0;
    adc = 0;
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    guest_line = 0;
    adcs = 0;
    adc = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (adcs > 0 && adc == adcs + 1) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest_line++;
        guest = guest $0 "\n";
        if ($0 ~ /adcs[[:space:]]+w5, w1, w2/) {
            adcs = guest_line;
        } else if ($0 ~ /adc[[:space:]]+w8, w6, w7/) {
            adc = guest_line;
        }
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$adcs_adc32_block" || die "failed to locate adjacent ADCS32->ADC32 host block"

# SBCS reg -> SBC: sbcs x5, x1, x2 / sbc x8, x6, x7 (真正相邻)
awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    sbcs = 0;
    sbc = 0;
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    sbcs = 0;
    sbc = 0;
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    guest_line = 0;
    sbcs = 0;
    sbc = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (sbcs > 0 && sbc == sbcs + 1) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest_line++;
        guest = guest $0 "\n";
        if ($0 ~ /sbcs[[:space:]]+x5, x1, x2/) {
            sbcs = guest_line;
        } else if ($0 ~ /sbc[[:space:]]+x8, x6, x7/) {
            sbc = guest_line;
        }
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$sbcs_sbc_block" || die "failed to locate adjacent SBCS->SBC host block"

# SBCS32 -> SBC32: sbcs w5, w1, w2 / sbc w8, w6, w7 (真正相邻)
awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    sbcs = 0;
    sbc = 0;
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    sbcs = 0;
    sbc = 0;
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    guest_line = 0;
    sbcs = 0;
    sbc = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (sbcs > 0 && sbc == sbcs + 1) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest_line++;
        guest = guest $0 "\n";
        if ($0 ~ /sbcs[[:space:]]+w5, w1, w2/) {
            sbcs = guest_line;
        } else if ($0 ~ /sbc[[:space:]]+w8, w6, w7/) {
            sbc = guest_line;
        }
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$sbcs_sbc32_block" || die "failed to locate adjacent SBCS32->SBC32 host block"

# ADCS32 -> ADC64 mixed-width negative block
awk '
BEGIN {
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    adcs = 0;
    adc = 0;
}
/^----------------$/ {
    if (want && host != "") {
        print host;
        exit 0;
    }
    in_guest = 0;
    in_host = 0;
    want = 0;
    guest = "";
    host = "";
    guest_line = 0;
    adcs = 0;
    adc = 0;
    next;
}
/^IN:[[:space:]]*$/ {
    in_guest = 1;
    in_host = 0;
    guest = "";
    host = "";
    want = 0;
    guest_line = 0;
    adcs = 0;
    adc = 0;
    next;
}
/^OUT:/ {
    in_guest = 0;
    in_host = 1;
    host = $0 "\n";
    if (adcs > 0 && adc == adcs + 1) {
        want = 1;
    }
    next;
}
{
    if (in_guest) {
        guest_line++;
        guest = guest $0 "\n";
        if ($0 ~ /adcs[[:space:]]+w5, w1, w2/) {
            adcs = guest_line;
        } else if ($0 ~ /adc[[:space:]]+x8, x6, x7/) {
            adc = guest_line;
        }
    } else if (in_host) {
        host = host $0 "\n";
    }
}
END {
    if (want && host != "") {
        print host;
        exit 0;
    }
    exit 1;
}
' "$log" >"$adcs32_adc64_block" || die "failed to locate mixed-width ADCS32->ADC64 host block"

# --- materialized ADDS -> ADCS direct 硬检查 ---
# 检查点：addq/addl 后接 adcq/adcl，中间不允许出现 canonical carry decode 胶水
grep -Eq '\baddq\b' "$adds_adcs_block" \
    || die "missing host addq for materialized ADDS->ADCS path"
grep -Eq '\badcq\b' "$adds_adcs_block" \
    || die "missing host adcq for materialized ADDS->ADCS path"
awk '
/addq/ && !seen_add {
    seen_add = 1;
    add_count = 1;
    next;
}
seen_add && !seen_adc && /addq/ {
    add_count++;
}
seen_add && !seen_adc && /adcq/ {
    seen_adc = 1;
    exit (bad || add_count != 1) ? 1 : 0;
}
seen_add && !seen_adc &&
(/\bshr[lq]\b/ || /\band[lq]\b/ || /\bxor[lq]\b/ ||
 /\bnot[lq]\b/ || /\bset[bcae]\b/) {
    bad = 1;
}
END {
    if (!seen_add || !seen_adc || bad || add_count != 1) {
        exit 1;
    }
}
' "$adds_adcs_block" || die "materialized ADDS->ADCS still has carry decode glue (shr/and/xor/not/setcc) between add and adc"

# --- materialized ADDS32 -> ADCS32 direct 硬检查 ---
grep -Eq '\baddl\b' "$adds_adcs32_block" \
    || die "missing host addl for materialized ADDS32->ADCS32 path"
grep -Eq '\badcl\b' "$adds_adcs32_block" \
    || die "missing host adcl for materialized ADDS32->ADCS32 path"
awk '
/addl/ && !seen_add {
    seen_add = 1;
    add_count = 1;
    next;
}
seen_add && !seen_adc && /addl/ {
    add_count++;
}
seen_add && !seen_adc && /adcl/ {
    seen_adc = 1;
    exit (bad || add_count != 1) ? 1 : 0;
}
seen_add && !seen_adc &&
(/\bshrl\b/ || /\bandl\b/ || /\bxorl\b/ ||
 /\bnotl\b/ || /\bset[bcae]\b/) {
    bad = 1;
}
END {
    if (!seen_add || !seen_adc || bad || add_count != 1) {
        exit 1;
    }
}
' "$adds_adcs32_block" || die "materialized ADDS32->ADCS32 still has carry decode glue (shr/and/xor/not/setcc) between add and adc"

# --- materialized SUBS -> SBCS direct 硬检查 ---
# 检查点：subq/subl 后接 sbbq/sbbl，中间不允许出现 canonical carry decode 胶水
grep -Eq '\bsubq\b' "$subs_sbcs_block" \
    || die "missing host subq for materialized SUBS->SBCS path"
grep -Eq '\bsbbq\b' "$subs_sbcs_block" \
    || die "missing host sbbq for materialized SUBS->SBCS path"
awk '
/subq/ && !seen_sub {
    seen_sub = 1;
    sub_count = 1;
    next;
}
seen_sub && !seen_sbb && /subq/ {
    sub_count++;
}
seen_sub && !seen_sbb && /sbbq/ {
    seen_sbb = 1;
    exit (bad || sub_count != 1) ? 1 : 0;
}
seen_sub && !seen_sbb &&
(/\bshr[lq]\b/ || /\band[lq]\b/ || /\bxor[lq]\b/ ||
 /\bnot[lq]\b/ || /\bset[bcae]\b/) {
    bad = 1;
}
END {
    if (!seen_sub || !seen_sbb || bad || sub_count != 1) {
        exit 1;
    }
}
' "$subs_sbcs_block" || die "materialized SUBS->SBCS still has borrow decode glue (shr/and/xor/not/setcc) between sub and sbb"

# --- materialized SUBS32 -> SBCS32 direct 硬检查 ---
grep -Eq '\bsubl\b' "$subs_sbcs32_block" \
    || die "missing host subl for materialized SUBS32->SBCS32 path"
grep -Eq '\bsbbl\b' "$subs_sbcs32_block" \
    || die "missing host sbbl for materialized SUBS32->SBCS32 path"
awk '
/subl/ && !seen_sub {
    seen_sub = 1;
    sub_count = 1;
    next;
}
seen_sub && !seen_sbb && /subl/ {
    sub_count++;
}
seen_sub && !seen_sbb && /sbbl/ {
    seen_sbb = 1;
    exit (bad || sub_count != 1) ? 1 : 0;
}
seen_sub && !seen_sbb &&
(/\bshrl\b/ || /\bandl\b/ || /\bxorl\b/ ||
 /\bnotl\b/ || /\bset[bcae]\b/) {
    bad = 1;
}
END {
    if (!seen_sub || !seen_sbb || bad || sub_count != 1) {
        exit 1;
    }
}
' "$subs_sbcs32_block" || die "materialized SUBS32->SBCS32 still has borrow decode glue (shr/and/xor/not/setcc) between sub and sbb"

# ------------------------------------------------------------------------
# 3.2 对 materialized ADCS/SBCS -> ADC/SBC 做 phase A1 direct 硬检查
# ------------------------------------------------------------------------

grep -Eq '\badcq\b' "$adcs_adc_block" \
    || die "missing host adcq for materialized ADCS->ADC path"
awk '
/adcq/ && !seen_adc {
    seen_adc = 1;
    adc_count = 1;
    next;
}
seen_adc && !seen_consumer && /adcq/ {
    adc_count++;
    seen_consumer = 1;
    exit (bad || adc_count != 2) ? 1 : 0;
}
seen_adc && !seen_consumer &&
(/\bshr[lq]\b/ || /\band[lq]\b/ || /\bxor[lq]\b/ ||
 /\bnot[lq]\b/ || /\bset[bcae]\b/ || /add[ql][[:space:]]+\$-1,/) {
    bad = 1;
}
END {
    if (!seen_adc || !seen_consumer || bad || adc_count != 2) {
        exit 1;
    }
}
' "$adcs_adc_block" || die "materialized ADCS->ADC still has carry decode glue between producer adc and consumer adc"

grep -Eq '\badcl\b' "$adcs_adc32_block" \
    || die "missing host adcl for materialized ADCS32->ADC32 path"
awk '
/adcl/ && !seen_adc {
    seen_adc = 1;
    adc_count = 1;
    next;
}
seen_adc && !seen_consumer && /adcl/ {
    adc_count++;
    seen_consumer = 1;
    exit (bad || adc_count != 2) ? 1 : 0;
}
seen_adc && !seen_consumer &&
(/\bshrl\b/ || /\bandl\b/ || /\bxorl\b/ ||
 /\bnotl\b/ || /\bset[bcae]\b/ || /addl[[:space:]]+\$-1,/) {
    bad = 1;
}
END {
    if (!seen_adc || !seen_consumer || bad || adc_count != 2) {
        exit 1;
    }
}
' "$adcs_adc32_block" || die "materialized ADCS32->ADC32 still has carry decode glue between producer adcl and consumer adcl"

grep -Eq '\bsbbq\b' "$sbcs_sbc_block" \
    || die "missing host sbbq for materialized SBCS->SBC path"
awk '
/sbbq/ && !seen_sbb {
    seen_sbb = 1;
    sbb_count = 1;
    next;
}
seen_sbb && !seen_consumer && /sbbq/ {
    sbb_count++;
    seen_consumer = 1;
    exit (bad || sbb_count != 2) ? 1 : 0;
}
seen_sbb && !seen_consumer &&
(/\bshr[lq]\b/ || /\band[lq]\b/ || /\bxor[lq]\b/ ||
 /\bnot[lq]\b/ || /\bset[bcae]\b/ || /add[ql][[:space:]]+\$-1,/) {
    bad = 1;
}
END {
    if (!seen_sbb || !seen_consumer || bad || sbb_count != 2) {
        exit 1;
    }
}
' "$sbcs_sbc_block" || die "materialized SBCS->SBC still has borrow decode glue between producer sbb and consumer sbb"

grep -Eq '\bsbbl\b' "$sbcs_sbc32_block" \
    || die "missing host sbbl for materialized SBCS32->SBC32 path"
awk '
/sbbl/ && !seen_sbb {
    seen_sbb = 1;
    sbb_count = 1;
    next;
}
seen_sbb && !seen_consumer && /sbbl/ {
    sbb_count++;
    seen_consumer = 1;
    exit (bad || sbb_count != 2) ? 1 : 0;
}
seen_sbb && !seen_consumer &&
(/\bshrl\b/ || /\bandl\b/ || /\bxorl\b/ ||
 /\bnotl\b/ || /\bset[bcae]\b/ || /addl[[:space:]]+\$-1,/) {
    bad = 1;
}
END {
    if (!seen_sbb || !seen_consumer || bad || sbb_count != 2) {
        exit 1;
    }
}
' "$sbcs_sbc32_block" || die "materialized SBCS32->SBC32 still has borrow decode glue between producer sbb and consumer sbb"

awk '
/adcl/ {
    pending = 1;
    next;
}
pending {
    if ($0 ~ /^[[:space:]]*$/) {
        next;
    }
    if ($0 ~ /adcq/) {
        exit 1;
    }
    pending = 0;
}
END {
    exit 0;
}
' "$adcs32_adc64_block" || die "mixed-width ADCS32->ADC64 unexpectedly used the compact same-width direct shape"

# ------------------------------------------------------------------------
# 3.3 对 compare-like CMN/CMP -> ADCS/SBCS 做负向检查（确保不走direct path）
# ------------------------------------------------------------------------

# 负向检查：真正相邻的 compare-like consumer 不能走 materialized direct 形状。
# CMN->ADCS fallback 需要先把 carry 物化成整数，再用 add $-1 seed CF，最后才 adc。
awk '
/add[ql][[:space:]]+\$-1,/ {
    saw_seed = 1;
}
/adc[ql]/ {
    found_adc = 1;
    status = saw_seed ? 0 : 1;
    exit;
}
END {
    if (!found_adc) {
        exit 1;
    }
    exit status;
}
' "$cmn_adcs_block" || die "compare-like CMN->ADCS is missing the carry-seed step before consumer adc"

# CMP->SBCS fallback 需要先把 borrow decode 成位，再通过 btl/cmc seed CF，最后才 sbb。
awk '
/btl/ {
    saw_btl = 1;
}
/cmc/ {
    saw_cmc = 1;
}
/sbb[ql]/ {
    found_sbb = 1;
    status = (saw_btl && saw_cmc) ? 0 : 1;
    exit;
}
END {
    if (!found_sbb) {
        exit 1;
    }
    exit status;
}
' "$cmp_sbcs_block" || die "compare-like CMP->SBCS is missing the borrow-seed step before consumer sbb"

echo "All codegen guard checks passed:"
echo "  - Materialized ADDS/ADDS32->ADCS and SUBS/SUBS32->SBCS use direct path (add/adc, sub/sbb without decode glue)"
echo "  - Materialized ADCS/ADCS32->ADC and SBCS/SBCS32->SBC use direct phase A1 shape (adc/adc, sbb/sbb without decode glue)"
echo "  - Mixed-width ADCS32->ADC64 stays outside the supported same-width compact direct shape"
echo "  - Truly adjacent compare-like CMN->ADCS and CMP->SBCS use fallback carry/borrow seeding before the consumer adc/sbb"
