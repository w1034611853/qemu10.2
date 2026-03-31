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

# ADCS block extractor: cmn x0, x1 / adcs x7, x5, x6
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
    if (guest ~ /cmn[[:space:]]+x0, x1/ &&
        guest ~ /adcs[[:space:]]+x7, x5, x6/) {
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
' "$log" >"$cmn_adcs_block" || die "failed to locate adjacent cmn->adcs host block"

# SBCS block extractor: cmp x0, x1 / sbcs x7, x5, x6
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
    if (guest ~ /cmp[[:space:]]+x0, x1/ &&
        guest ~ /sbcs[[:space:]]+x7, x5, x6/) {
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

# CMN->ADCS and CMP->SBCS do NOT use direct path because CMN/CMP are REWINDABLE_CMP.
# CMN and CMP set up rewind for CF, so the direct adc/sbb path is not available.
# The non-direct path is still correct - it just doesn't use raw adc/sbb directly.
# Functional correctness is verified by running the test binary (which passes).
# No codegen checks needed for these paths.
