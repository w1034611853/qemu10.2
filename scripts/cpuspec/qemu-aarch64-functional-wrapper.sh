#!/usr/bin/env bash
#
# Wrapper for SPEC CPU2017 functional smoke runs under WSL.
#
# SPEC's native specinvoke sometimes observes non-monotonic wall-clock deltas on
# short 557.xz_r test-size children.  The guest command succeeds, but specinvoke
# may stop early before all output files are created.  Keep this wrapper out of
# performance runs; it deliberately adds a small post-run delay only for the
# short 557.xz_r test workload.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)

qemu_bin=${QEMU_AARCH64_BIN:-"$repo_root/build-aarch64-linux-user/qemu-aarch64"}
post_sleep=${QEMU_SPEC_557_XZ_POST_SLEEP_SEC:-2}
stabilize=${QEMU_SPEC_STABILIZE_557_XZ:-1}

if [[ ! -x "$qemu_bin" ]]; then
    echo "qemu-aarch64 wrapper: executable not found: $qemu_bin" >&2
    exit 127
fi

set +e
"$qemu_bin" "$@"
rc=$?
set -e

if [[ "$rc" -eq 0 && "$stabilize" != 0 ]]; then
    joined_args=" $* "
    if [[ "$joined_args" == *"xz_r_base."* &&
          "$joined_args" == *" cpu2006docs.tar.xz "* ]]; then
        sleep "$post_sleep"
    fi
fi

exit "$rc"
