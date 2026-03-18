# A64 cmp+jcc Follow-up Perf Results

Date: 2026-03-18

Branch: `a64-x86-status4-v10.2.0`

This note records the focused performance data for the raw-x86-flags
optimization that replaced branch-edge `status4` materialization with a
lighter raw-flags capture plus lazy decode.

## Setup

- Baseline binary:
  `/home/wangruoyu/qemu10.2_clean/build-aarch64-linux-user/qemu-aarch64`
- Current binary:
  `/home/wangruoyu/qemu10.2/build-aarch64-linux-user/qemu-aarch64`
- Benchmark binary:
  `/tmp/a64_cmpbench`
- Iteration count:
  `100000000`
- Host timing command:
  `/usr/bin/time -f '%e'`

## Correctness

The implementation change in this revision passed:

- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-nzcv-status4 run-cmpstress-o3`

## Results

### `branch`

Command:

```bash
/usr/bin/time -f '%e' ... qemu-aarch64 /tmp/a64_cmpbench branch 100000000
```

- Baseline runs: `0.19 0.20 0.18 0.17 0.19`
- Current runs: `0.17 0.17 0.15 0.17 0.18`
- Baseline mean: `0.186s`
- Current mean: `0.168s`
- Relative change: `+9.7%` faster than `v10.2.0`

### `branch_gap4`

Command:

```bash
/usr/bin/time -f '%e' ... qemu-aarch64 /tmp/a64_cmpbench branch_gap4 100000000
```

- Baseline runs: `0.24 0.25 0.24 0.25 0.23`
- Current runs: `0.23 0.23 0.22 0.24 0.21`
- Baseline mean: `0.242s`
- Current mean: `0.226s`
- Relative change: `+6.6%` faster than `v10.2.0`

### `csel`

Command:

```bash
/usr/bin/time -f '%e' ... qemu-aarch64 /tmp/a64_cmpbench csel 100000000
```

- Baseline runs: `0.17 0.18 0.17 0.17 0.18`
- Current runs: `0.17 0.17 0.16 0.18 0.17`
- Baseline mean: `0.174s`
- Current mean: `0.170s`
- Relative change: `+2.3%` faster than `v10.2.0`

## Scope Note

These numbers are focused user-mode microbenchmarks aimed at the
`cmp+b.cond` / compare-consumer fast paths. Full Linux boot and broader
workload re-runs were not repeated for this exact raw-flags revision in this
commit.
