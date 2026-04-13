#!/usr/bin/env bash
#
# Lightweight SPEC CPU2017 train-input performance comparison for QEMU
# aarch64-linux-user.  This intentionally bypasses the functional wrapper and
# does not use SPEC's specinvoke timing path.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)

qemu_new=${QEMU_NEW:-"${1:-$repo_root/build-aarch64-linux-user/qemu-aarch64}"}
qemu_base=${QEMU_BASE:-"${2:-/home/wangruoyu/qemu10.2_clean/build-aarch64-linux-user/qemu-aarch64}"}
spec_root=${SPEC_ROOT:-/home/wangruoyu/cpuspec2017}
guest_sysroot=${GUEST_SYSROOT:-/usr/aarch64-linux-gnu}
repeats=${REPEATS:-3}
perf_benchmarks=${PERF_BENCHMARKS:-"500.perlbench_r 502.gcc_r 505.mcf_r 531.deepsjeng_r 541.leela_r 557.xz_r"}
output_dir=${OUTPUT_DIR:-"${TMPDIR:-/tmp}/qemu-cpuspec-perf-results"}
output_file=${OUTPUT_FILE:-"$output_dir/cpuspec-train-compare-$(date +%Y%m%d-%H%M%S).tsv"}

run() {
    printf '\n>>> %s\n' "$*" >&2
    "$@"
}

require_file() {
    if [[ ! -e "$1" ]]; then
        echo "missing required path: $1" >&2
        exit 1
    fi
}

require_file "$qemu_new"
require_file "$qemu_base"
require_file "$spec_root"
mkdir -p "$output_dir"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/qemu-cpuspec-perf.XXXXXX")
cleanup() {
    rm -rf "$work_dir"
}
trap cleanup EXIT

run_one() {
    local qemu=$1
    local cwd=$2
    shift 2
    local start_ns end_ns
    start_ns=$(date +%s%N)
    (
        cd "$cwd"
        "$qemu" -L "$guest_sysroot" "$@" >/dev/null 2>&1
    )
    end_ns=$(date +%s%N)
    echo $(((end_ns - start_ns) / 1000000))
}

run_avg() {
    local qemu=$1
    local cwd=$2
    shift 2
    local total=0
    local i elapsed
    for ((i = 1; i <= repeats; i++)); do
        elapsed=$(run_one "$qemu" "$cwd" "$@")
        total=$((total + elapsed))
        printf '    run %d: %sms\n' "$i" "$elapsed" >&2
    done
    echo $((total / repeats))
}

speedup_ratio() {
    awk -v new_ms="$1" -v base_ms="$2" 'BEGIN {
        if (new_ms <= 0) {
            print "nan";
        } else {
            printf "%.4f", base_ms / new_ms;
        }
    }'
}

printf "# qemu_new\t%s\n" "$qemu_new" >"$output_file"
printf "# qemu_base\t%s\n" "$qemu_base" >>"$output_file"
printf "# repeats\t%s\n" "$repeats" >>"$output_file"
printf "# benchmarks\t%s\n" "$perf_benchmarks" >>"$output_file"
printf "benchmark\tnew_ms\tbase_ms\tspeedup_base_over_new\n" >>"$output_file"

declare -a tests=(
    "500.perlbench_r|$work_dir/500.perlbench_r|$work_dir/500.perlbench_r/perlbench_r_base.mytest-64|-I./lib|diffmail.pl|2|550|15|24|23|100"
    "502.gcc_r|$work_dir|$spec_root/benchspec/CPU/502.gcc_r/exe/cpugcc_r_base.mytest-64|-o|$work_dir/gcc_test.s|$spec_root/benchspec/CPU/502.gcc_r/data/train/input/200.c"
    "505.mcf_r|$work_dir|$spec_root/benchspec/CPU/505.mcf_r/exe/mcf_r_base.mytest-64|$spec_root/benchspec/CPU/505.mcf_r/data/train/input/inp.in"
    "531.deepsjeng_r|$work_dir|$spec_root/benchspec/CPU/531.deepsjeng_r/exe/deepsjeng_r_base.mytest-64|$spec_root/benchspec/CPU/531.deepsjeng_r/data/train/input/train.txt"
    "541.leela_r|$work_dir|$spec_root/benchspec/CPU/541.leela_r/exe/leela_r_base.mytest-64|$spec_root/benchspec/CPU/541.leela_r/data/train/input/train.sgf"
    "557.xz_r|$work_dir/557.xz_r|$work_dir/557.xz_r/xz_r_base.mytest-64|input.combined.xz|40|a841f68f38572a49d86226b7ff5baeb31bd19dc637a922a972b2e6d1257a890f6a544ecab967c313e370478c74f760eb229d4eef8a8d2836d233d3e9dd1430bf|6356684|-1|8"
)

want_bench() {
    local candidate=$1
    local selected
    for selected in $perf_benchmarks; do
        [[ "$selected" == "$candidate" ]] && return 0
    done
    return 1
}

for test_spec in "${tests[@]}"; do
    IFS='|' read -r -a fields <<<"$test_spec"
    name=${fields[0]}
    cwd=${fields[1]}
    exe=${fields[2]}
    args=("${fields[@]:3}")

    if ! want_bench "$name"; then
        continue
    fi

    if [[ "$name" == "500.perlbench_r" && ! -e "$cwd" ]]; then
        cp -a "$spec_root/benchspec/CPU/500.perlbench_r/run/run_base_train_mytest-64.0000" "$cwd"
    fi
    if [[ "$name" == "557.xz_r" && ! -e "$cwd" ]]; then
        cp -a "$spec_root/benchspec/CPU/557.xz_r/run/run_base_train_mytest-64.0000" "$cwd"
    fi

    require_file "$cwd"
    require_file "$exe"
    for arg in "${args[@]}"; do
        if [[ "$arg" == "$spec_root/"* ]]; then
            require_file "$arg"
        fi
    done

    printf '\n=== %s ===\n' "$name" >&2
    printf '  new QEMU:\n' >&2
    new_ms=$(run_avg "$qemu_new" "$cwd" "$exe" "${args[@]}")
    printf '  baseline QEMU:\n' >&2
    base_ms=$(run_avg "$qemu_base" "$cwd" "$exe" "${args[@]}")
    ratio=$(speedup_ratio "$new_ms" "$base_ms")
    printf "%s\t%s\t%s\t%s\n" "$name" "$new_ms" "$base_ms" "$ratio" | tee -a "$output_file"
done

printf '\nResults: %s\n' "$output_file"
