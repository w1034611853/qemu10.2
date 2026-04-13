#!/usr/bin/env bash
#
# Build QEMU, run the focused AArch64 NZCV checks, then run the SPEC CPU2017
# test-size smoke set used for this optimization line.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)

build_dir=${BUILD_DIR:-"$repo_root/build-aarch64-linux-user"}
qemu_bin=${QEMU_AARCH64_BIN:-"$build_dir/qemu-aarch64"}
spec_root=${SPEC_ROOT:-/home/wangruoyu/cpuspec2017}
spec_config=${SPEC_CONFIG:-"$spec_root/config/qemu_aarch64_tcg.cfg"}
guest_sysroot=${GUEST_SYSROOT:-/usr/aarch64-linux-gnu}
benchmarks=${SPEC_BENCHMARKS:-"502.gcc_r 505.mcf_r 531.deepsjeng_r 541.leela_r 557.xz_r"}
wrapper=${QEMU_AARCH64_FUNCTIONAL_WRAPPER:-"$script_dir/qemu-aarch64-functional-wrapper.sh"}

run() {
    printf '\n>>> %s\n' "$*"
    "$@"
}

require_file() {
    if [[ ! -e "$1" ]]; then
        echo "missing required path: $1" >&2
        exit 1
    fi
}

require_file "$spec_root/bin/runcpu"
require_file "$spec_config"
require_file "$wrapper"

if [[ "${SKIP_QEMU_BUILD:-0}" != 1 ]]; then
    run ninja -C "$build_dir" qemu-aarch64
fi

require_file "$qemu_bin"

if [[ "${SKIP_TCG_TEST_BUILD:-0}" != 1 ]]; then
    run make -C "$build_dir/tests/tcg/aarch64-linux-user"
fi

focused_checks=(
    "check-adc-sbc-host-direct.sh adc-sbc-host-direct"
    "check-cmp-bcond-gap-host-direct.sh cmp-bcond-gap-host-direct"
    "check-cmp-csel-gap-host-direct.sh cmp-csel-gap-host-direct"
    "check-cmp-ccmp-gap-host-direct.sh cmp-ccmp-gap-host-direct"
    "check-cmp-fccmp-gap-host-direct.sh cmp-fccmp-gap-host-direct"
    "check-cmp-csel-bcond-chain-host-direct.sh cmp-csel-bcond-chain-host-direct"
    "check-cmp-csel-ccmp-chain-host-direct.sh cmp-csel-ccmp-chain-host-direct"
    "check-cmp-csel-csel-chain-host-direct.sh cmp-csel-csel-chain-host-direct"
    "check-cmp-ccmp-bcond-chain-host-direct.sh cmp-ccmp-bcond-chain-host-direct"
    "check-cmp-ccmp-ccmp-chain-host-direct.sh cmp-ccmp-ccmp-chain-host-direct"
    "check-cmp-ccmp-csel-bcond-chain-host-direct.sh cmp-ccmp-csel-bcond-chain-host-direct"
    "check-cmp-ccmp-csel-csel-chain-host-direct.sh cmp-ccmp-csel-csel-chain-host-direct"
    "check-cmp-ccmp-csel-ccmp-chain-host-direct.sh cmp-ccmp-csel-ccmp-chain-host-direct"
    "check-cmp-ccmp-ccmp-csel-bcond-chain-host-direct.sh cmp-ccmp-ccmp-csel-bcond-chain-host-direct"
    "check-cmp-ccmp-ccmp-ccmp-chain-host-direct.sh cmp-ccmp-ccmp-ccmp-chain-host-direct"
    "check-cmp-ccmp-ccmp-ccmp-csel-bcond-chain-host-direct.sh cmp-ccmp-ccmp-ccmp-csel-bcond-chain-host-direct"
    "check-nzcv-status4-raw-ccop-specialization.sh nzcv-status4"
)

for entry in "${focused_checks[@]}"; do
    read -r checker binary <<<"$entry"
    run bash "$repo_root/tests/tcg/aarch64/$checker" \
        "$qemu_bin" "$build_dir/tests/tcg/aarch64-linux-user/$binary"
done

run "$qemu_bin" -L "$guest_sysroot" \
    "$build_dir/tests/tcg/aarch64-linux-user/nzcv-status4"

(
    cd "$spec_root"
    export QEMU_AARCH64_BIN="$qemu_bin"
    export QEMU_SPEC_STABILIZE_557_XZ="${QEMU_SPEC_STABILIZE_557_XZ:-1}"
    export QEMU_SPEC_557_XZ_POST_SLEEP_SEC="${QEMU_SPEC_557_XZ_POST_SLEEP_SEC:-2}"

    # The wrapper is only for functional smoke.  It protects 557.xz_r test-size
    # from WSL/specinvoke negative elapsed-time artifacts and must not be used
    # for timing or performance comparisons.
    printf '\n>>> ./bin/runcpu ... %s\n' "$benchmarks"
    spec_output=$(mktemp "${TMPDIR:-/tmp}/qemu-cpuspec-functional.XXXXXX")
    set +e
    ./bin/runcpu \
        --config "$spec_config" \
        --define "qemu=$wrapper" \
        --define "guest_sysroot=$guest_sysroot" \
        --size=test \
        --iterations=1 \
        --action=run \
        --nobuild \
        $benchmarks 2>&1 | tee "$spec_output"
    runcpu_rc=${PIPESTATUS[0]}
    set -e

    if [[ "$runcpu_rc" -ne 0 ]]; then
        rm -f "$spec_output"
        exit "$runcpu_rc"
    fi
    if grep -Eq '(^|[[:space:]])Error:[[:space:]]+[0-9]+x' "$spec_output"; then
        echo "SPEC reported benchmark errors; see runcpu log above" >&2
        rm -f "$spec_output"
        exit 1
    fi
    if ! grep -Eq '(^|[[:space:]])Success:[[:space:]]+[0-9]+x' "$spec_output"; then
        echo "SPEC did not report a benchmark Success line" >&2
        rm -f "$spec_output"
        exit 1
    fi
    rm -f "$spec_output"
)
