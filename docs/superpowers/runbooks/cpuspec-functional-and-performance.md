# SPEC CPU2017 Functional and Performance Runbook

This runbook is the handoff entry point for agents that need to validate the
AArch64-on-x86 NZCV optimization line.

## Scope

- Functional smoke:
  - builds `qemu-aarch64`
  - runs focused AArch64 NZCV codegen checks
  - runs the SPEC CPU2017 `test` workload smoke set
- Performance comparison:
  - compares optimized QEMU against a clean QEMU on selected SPEC CPU2017
    train-input commands
  - avoids the functional-only `557.xz_r` wrapper so timing is not polluted

## Required Local Paths

The scripts default to the current workstation layout:

```bash
SPEC_ROOT=/home/wangruoyu/cpuspec2017
GUEST_SYSROOT=/usr/aarch64-linux-gnu
BUILD_DIR=/home/wangruoyu/qemu10.2/build-aarch64-linux-user
QEMU_AARCH64_BIN=/home/wangruoyu/qemu10.2/build-aarch64-linux-user/qemu-aarch64
QEMU_BASE=/home/wangruoyu/qemu10.2_clean/build-aarch64-linux-user/qemu-aarch64
```

Override these environment variables if an agent is running from another tree.

## 557.xz_r Test-Size Harness Fix

`557.xz_r` previously failed in some SPEC `test` runs with messages like:

```text
ERROR: negative elapsed time detected
Can't open input file cpu2006docs.tar-1-0.out
```

Root-cause evidence:

- the failing child command returned `rc=0`
- direct sequential execution of the same 12 `557.xz_r test` commands generated
  all expected output files
- `specdiff` passed for those output files
- the failure was caused by native SPEC `specinvoke` observing a non-monotonic
  wall-clock delta under WSL and stopping before all output files were created

The fix is not a translator change.  Functional smoke uses:

```bash
scripts/cpuspec/qemu-aarch64-functional-wrapper.sh
```

That wrapper forwards to the real `qemu-aarch64`, then adds a short post-run
delay only for an `xz_r_base.*` executable path plus `cpu2006docs.tar.xz`.
This keeps SPEC `test` functional validation stable.

Do not use this wrapper for performance runs.

## Functional Smoke

Run the default functional suite:

```bash
scripts/cpuspec/run-functional-smoke.sh
```

Useful overrides:

```bash
SKIP_QEMU_BUILD=1 \
SKIP_TCG_TEST_BUILD=1 \
SPEC_BENCHMARKS="502.gcc_r 505.mcf_r 531.deepsjeng_r 541.leela_r 557.xz_r" \
scripts/cpuspec/run-functional-smoke.sh
```

To rerun only the formerly failing SPEC case while still running focused checks:

```bash
SKIP_QEMU_BUILD=1 \
SKIP_TCG_TEST_BUILD=1 \
SPEC_BENCHMARKS="557.xz_r" \
scripts/cpuspec/run-functional-smoke.sh
```

Success criteria:

- every focused checker exits `0`
- `nzcv-status4` prints `PASS`
- SPEC reports `Success` for each selected benchmark
- the runner fails if `runcpu` prints a benchmark `Error:` line, even if the
  native `runcpu` process itself exits `0`

Known fresh validation:

- `557.xz_r` with the wrapper passed as `CPU2017.111.*`
- the functional script narrow run with `SPEC_BENCHMARKS=557.xz_r` passed as
  `CPU2017.112.*`
- after making the wrapper path-tolerant for
  `../run_base_test_mytest-64.0000/xz_r_base.mytest-64`, the same narrow
  functional script run passed as `CPU2017.114.*`
- `CPU2017.114.*` generated all 12 expected `cpu2006docs.tar-*.out` files and
  `speccmds.out` had no `negative elapsed` record
- after adding the runner-side SPEC output check, the same narrow functional
  script run passed as `CPU2017.115.*`

## Performance Comparison

Run the default train-input comparison:

```bash
scripts/cpuspec/run-performance-compare.sh
```

Recommended first pass after a correctness change:

```bash
REPEATS=1 \
PERF_BENCHMARKS="502.gcc_r 505.mcf_r 531.deepsjeng_r 541.leela_r" \
scripts/cpuspec/run-performance-compare.sh
```

More stable comparison:

```bash
REPEATS=3 \
PERF_BENCHMARKS="500.perlbench_r 502.gcc_r 505.mcf_r 531.deepsjeng_r 541.leela_r 557.xz_r" \
OUTPUT_DIR=/home/wangruoyu/qemu10.2/performance_report/manual \
scripts/cpuspec/run-performance-compare.sh
```

Output is a TSV file with:

```text
benchmark	new_ms	base_ms	speedup_base_over_new
```

Interpretation:

- `speedup_base_over_new > 1.0`: optimized QEMU is faster
- `speedup_base_over_new < 1.0`: optimized QEMU is slower

The script intentionally runs benchmark processes in a temporary directory so
SPEC-generated output files such as `mcf.out` do not dirty the repository.
For workloads whose train command depends on SPEC-staged auxiliary files
(`500.perlbench_r`, `557.xz_r`), it first copies the corresponding
`run_base_train_mytest-64.0000` directory to that temporary workspace.

Known fresh validation:

- syntax check:
  `bash -n scripts/cpuspec/qemu-aarch64-functional-wrapper.sh scripts/cpuspec/run-functional-smoke.sh scripts/cpuspec/run-performance-compare.sh`
- short performance runner smoke:
  `REPEATS=1 PERF_BENCHMARKS="500.perlbench_r 557.xz_r" scripts/cpuspec/run-performance-compare.sh`
- short smoke output:
  - `500.perlbench_r`: `new_ms=4`, `base_ms=4`, `speedup_base_over_new=1.0000`
  - `557.xz_r`: `new_ms=37159`, `base_ms=38190`, `speedup_base_over_new=1.0277`
  - result file: `/tmp/qemu-cpuspec-perf-results/cpuspec-train-compare-20260413-144502.tsv`

Treat this as script validation only.  It is a one-repeat subset and is not a
replacement for the broader performance report.

## Current Performance Warning

The latest user-provided comparison showed optimized QEMU slower across all
listed workloads:

```text
500.perlbench_r: 0.722x
502.gcc_r:       0.771x
505.mcf_r:       0.775x
531.deepsjeng_r: 0.799x
541.leela_r:     0.843x
557.xz_r:        0.866x
```

This pattern looks like a global overhead, not a single bad consumer path.  The
next performance investigation should compare translation/codegen volume and
remaining always-on RAW/pending bookkeeping against clean QEMU before adding
more direct paths.
