# SPEC CPU2017 Seven-Benchmark Test-Size Runbook

## Goal

Provide a repeatable way to run the seven commonly used SPEC CPU2017 integer
benchmarks at `test` size against the local AArch64-on-x86 QEMU build, and to
interpret the results correctly.

The benchmark set covered here is:

- `500.perlbench_r`
- `502.gcc_r`
- `505.mcf_r`
- `523.xalancbmk_r`
- `531.deepsjeng_r`
- `541.leela_r`
- `557.xz_r`

## Scope

This document is for:

- quick correctness checks using SPEC `test` size
- repeatable local runs from the current QEMU tree
- understanding the one important exception:
  `500.perlbench_r test`

This document is **not** the main performance methodology. For performance,
prefer the existing microbench and `train`-size workflows.

## Environment Assumptions

These paths are assumed throughout:

```sh
QEMU_REPO=/home/wangruoyu/qemu10.2
QEMU_BIN=$QEMU_REPO/build-aarch64-linux-user/qemu-aarch64
SPEC=/home/wangruoyu/cpuspec2017
SPEC_CFG=$SPEC/config/qemu_aarch64_tcg.cfg
```

The SPEC config already points `submit` at the local QEMU binary path.

## Benchmarks

```sh
BENCHES="500.perlbench_r 502.gcc_r 505.mcf_r 523.xalancbmk_r 531.deepsjeng_r 541.leela_r 557.xz_r"
```

## Preconditions

### 1. QEMU build is up to date

```sh
cd "$QEMU_REPO"
ninja -C build-aarch64-linux-user qemu-aarch64
```

Expected:

- link succeeds
- resulting binary exists at:
  `$QEMU_REPO/build-aarch64-linux-user/qemu-aarch64`

### 2. SPEC binaries are already built

This runbook assumes the seven SPEC benchmarks have already been built under
label `mytest-64`.

If not, build them first:

```sh
cd "$SPEC"
./bin/runcpu \
  --config "$SPEC_CFG" \
  --action=build \
  --iterations=1 \
  $BENCHES
```

## Standard Seven-Benchmark Test-Size Run

This is the normal command for the full seven-benchmark `test` sweep:

```sh
cd "$SPEC"
./bin/runcpu \
  --config "$SPEC_CFG" \
  --size=test \
  --iterations=1 \
  --action=run \
  --nobuild \
  $BENCHES
```

What this does:

- uses the current QEMU binary via the SPEC config
- runs one `test`-size iteration
- does not rebuild the SPEC binaries

## Result Files

After the run, SPEC writes a numbered result set in:

```sh
$SPEC/result/
```

The most important files are:

- `CPU2017.NNN.log`
- `CPU2017.NNN.intrate.test.txt`
- `CPU2017.NNN.intrate.test.csv`
- `CPU2017.NNN.intrate.test.cfg`
- `CPU2017.NNN.intrate.test.rsf`

To find the newest result bundle:

```sh
ls -lt "$SPEC/result" | head
```

## Quick Result Extraction

### Summary from the text report

```sh
LATEST_TXT=$(ls -t "$SPEC"/result/CPU2017.*.intrate.test.txt | head -n 1)
sed -n '1,220p' "$LATEST_TXT"
```

### Success/Error lines from the raw log

```sh
LATEST_LOG=$(ls -t "$SPEC"/result/CPU2017.*.log | head -n 1)
grep -E "(Success|Error):" "$LATEST_LOG"
```

### Confirm which command produced the result bundle

```sh
LATEST_CFG=$(ls -t "$SPEC"/result/CPU2017.*.intrate.test.cfg | head -n 1)
sed -n '1,8p' "$LATEST_CFG"
```

## Interpreting Outcomes

### Good outcome

If all seven pass, you should see only `Success:` lines and no `Error:` lines.

### Bad outcome

Any of the following means the run is not a clean correctness pass:

- `Error: ... (Miscompare)`
- non-zero run return code
- missing output files
- shell/loader errors in benchmark-local `*.err`

## Important Exception: `500.perlbench_r test`

`500.perlbench_r test` is special.

The top-level SPEC run launches the outer Perl interpreter through QEMU, but
the Perl test harness then launches *nested* Perl subprocesses internally.
Those nested subprocesses can escape the outer `qemu-aarch64` wrapper.

When that happens, the run shows symptoms like:

- `makerand.out` compares cleanly
- `test.out` miscompares from the first line
- `test.err` contains many copies of:

```text
perlbench_r_base.mytest-64: 1: Syntax error: word unexpected (expecting ")")
```

That pattern is **not** by itself evidence of an NZCV optimization bug. It is a
known `test`-workload execution-mode problem.

For that specific case, use the dedicated workaround document:

- [2026-04-02-perlbench-test-workload-qemu-wrapper-workaround.md](/home/wangruoyu/qemu10.2/docs/superpowers/summaries/2026-04-02-perlbench-test-workload-qemu-wrapper-workaround.md)

## Recommended Practical Policy

For routine branch validation:

- run all seven benchmarks at `test` size
- treat six of them normally
- treat `500.perlbench_r test` with caution

Recommended interpretation:

- if one of `502/505/523/531/541/557` fails, that is a real correctness alarm
- if `500.perlbench_r test` alone fails with the nested-perl syntax-error
  signature above, do **not** immediately classify it as an NZCV bug
- instead, either:
  - re-run `500.perlbench_r` with the wrapper workaround
  - or fall back to `train`-size validation for that benchmark

## Individual Benchmark Re-run Commands

Use these when you want to re-run only one benchmark at `test` size.

### `500.perlbench_r`

```sh
cd "$SPEC"
./bin/runcpu \
  --config "$SPEC_CFG" \
  --size=test \
  --iterations=1 \
  --action=run \
  --nobuild \
  500.perlbench_r
```

### `502.gcc_r`

```sh
cd "$SPEC"
./bin/runcpu \
  --config "$SPEC_CFG" \
  --size=test \
  --iterations=1 \
  --action=run \
  --nobuild \
  502.gcc_r
```

### `505.mcf_r`

```sh
cd "$SPEC"
./bin/runcpu \
  --config "$SPEC_CFG" \
  --size=test \
  --iterations=1 \
  --action=run \
  --nobuild \
  505.mcf_r
```

### `523.xalancbmk_r`

```sh
cd "$SPEC"
./bin/runcpu \
  --config "$SPEC_CFG" \
  --size=test \
  --iterations=1 \
  --action=run \
  --nobuild \
  523.xalancbmk_r
```

### `531.deepsjeng_r`

```sh
cd "$SPEC"
./bin/runcpu \
  --config "$SPEC_CFG" \
  --size=test \
  --iterations=1 \
  --action=run \
  --nobuild \
  531.deepsjeng_r
```

### `541.leela_r`

```sh
cd "$SPEC"
./bin/runcpu \
  --config "$SPEC_CFG" \
  --size=test \
  --iterations=1 \
  --action=run \
  --nobuild \
  541.leela_r
```

### `557.xz_r`

```sh
cd "$SPEC"
./bin/runcpu \
  --config "$SPEC_CFG" \
  --size=test \
  --iterations=1 \
  --action=run \
  --nobuild \
  557.xz_r
```

## Useful Benchmark-Local Files

When a specific benchmark fails, inspect its newest run directory under:

```sh
$SPEC/benchspec/CPU/<benchmark>/run/
```

Files that matter most:

- `speccmds.out`
- `speccmds.cmd`
- `compare.out`
- `compare.err`
- benchmark-specific `*.err`
- benchmark-specific `*.out`
- benchmark-specific `*.mis`

For `500.perlbench_r test`, the most informative files are usually:

- `test.err`
- `test.out`
- `test.out.mis`
- `t/TEST`

## Suggested Minimal Validation Flow

### Normal branch check

```sh
cd "$QEMU_REPO"
ninja -C build-aarch64-linux-user qemu-aarch64

cd "$SPEC"
./bin/runcpu \
  --config "$SPEC_CFG" \
  --size=test \
  --iterations=1 \
  --action=run \
  --nobuild \
  $BENCHES
```

Then:

```sh
LATEST_LOG=$(ls -t "$SPEC"/result/CPU2017.*.log | head -n 1)
grep -E "(Success|Error):" "$LATEST_LOG"
```

### If only `500.perlbench_r` fails

1. Check whether the signature matches the nested-perl issue:

```sh
find "$SPEC/benchspec/CPU/500.perlbench_r/run" -name test.err -print | tail -n 1 | \
while read f; do
  sed -n '1,20p' "$f"
done
```

2. If you see repeated shell syntax errors, follow:

- [2026-04-02-perlbench-test-workload-qemu-wrapper-workaround.md](/home/wangruoyu/qemu10.2/docs/superpowers/summaries/2026-04-02-perlbench-test-workload-qemu-wrapper-workaround.md)

## Current Known Limitation

This runbook does not automatically solve the nested guest self-exec problem
inside `500.perlbench_r test`. It only documents:

- the normal seven-benchmark `test` workflow
- how to identify the special `perlbench` failure mode
- where to find the dedicated workaround
