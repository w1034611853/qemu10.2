# A64 cmp+jcc Follow-up Perf Results

## 2026-03-28 Debug Note: Shadow NZCV Reference

- 新增独立 debug shadow：
  - `a64_debug_shadow_nzcv`
  - `a64_debug_shadow_valid`
- producer 在写 ARM 语义 NZCV 时同步更新 shadow
- consumer / current-NZCV / cmp-pending branch fastpath 现在都拿 shadow 做 reference

### 验证

- `ninja -C build-aarch64-linux-user qemu-aarch64`：通过
- `nzcv-status4`：PASS
- `cmpstress-o3`：PASS

### 531.deepsjeng_r train

- `QEMU_A64_CC_DEBUG=1` 下：
  - 没有触发 shadow mismatch
  - 但输出前缀仍然很早偏离参考输出

### 当前含义

- 已覆盖的 canonical flags 语义路径暂时没有暴露第一处真实 mismatch
- 问题可能在：
  - 尚未接入 shadow 的 writer
  - 非 canonical-flags 路径
  - 其它 always-active 静态差异
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

## 2026-03-19 Follow-up (cmp+branch single-capture op)

This follow-up measured the branch-op-integrated raw-flags capture
implementation (with correctness passing on:
`run-nzcv-status4` and `run-cmpstress-o3`).

- Baseline binary:
  `/home/wangruoyu/qemu10.2_clean/build-aarch64-linux-user/qemu-aarch64`
- Current binary:
  `/home/wangruoyu/qemu10.2/build-aarch64-linux-user/qemu-aarch64`
- Benchmark binary:
  `/tmp/a64_cmpbench`
- Iteration count:
  `100000000`

### `branch`

- Baseline runs: `0.18 0.16 0.16 0.16 0.16`
- Current runs: `0.16 0.16 0.16 0.16 0.16`
- Baseline mean: `0.164s`
- Current mean: `0.160s`
- Relative change: `+2.4%`

### `branch_gap4`

- Baseline runs: `0.21 0.20 0.21 0.21 0.21`
- Current runs: `0.20 0.21 0.20 0.20 0.21`
- Baseline mean: `0.208s`
- Current mean: `0.204s`
- Relative change: `+1.9%`

### `csel`

- Baseline runs: `0.14 0.14 0.14 0.14 0.14`
- Current runs: `0.14 0.14 0.14 0.14 0.14`
- Baseline mean: `0.140s`
- Current mean: `0.140s`
- Relative change: `~0%`

## 2026-03-19 Follow-up (register-free `setcc` raw capture)

This variant replaced the branch-path raw capture from `push/pop + lahf/seto`
to register-free `seto/setb/sete/sets` stores into `x86_raw_flags` bytes.

Correctness:

- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

### `/tmp/a64_cmpbench` (100000000 iterations)

#### `branch`

- Baseline runs: `0.24 0.23 0.23 0.23 0.23`
- Current runs: `0.23 0.23 0.22 0.22 0.23`
- Baseline mean: `0.232s`
- Current mean: `0.226s`
- Relative change: `+2.6%`

#### `branch_gap4`

- Baseline runs: `0.29 0.29 0.29 0.28 0.28`
- Current runs: `0.28 0.27 0.29 0.28 0.28`
- Baseline mean: `0.286s`
- Current mean: `0.280s`
- Relative change: `+2.1%`

#### `csel`

- Baseline runs: `0.17 0.17 0.17 0.16 0.17`
- Current runs: `0.21 0.21 0.21 0.20 0.21`
- Baseline mean: `0.168s`
- Current mean: `0.208s`
- Relative change: `-23.8%`

### `cmpstress-o3` repeated run (300 invocations)

- Baseline: `2.97s`
- Current: `2.94s`
- Relative change: `+1.0%`

## 2026-03-19 Follow-up (remove `push/pop` from raw capture)

This variant keeps `lahf + seto + store(rawflags)` but removes
`push %rax / pop %rax` in the branch-integrated capture path.

Correctness:

- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass
- `/tmp/a64_cmpbench` output equality pass (`branch`, `branch_gap4`, `csel`)

### `/tmp/a64_cmpbench` (100000000 iterations)

#### `branch`

- Baseline runs: `0.22 0.22 0.22 0.22 0.22`
- Current runs: `0.16 0.15 0.16 0.16 0.15`
- Baseline mean: `0.220s`
- Current mean: `0.156s`
- Relative change: `+29.1%`

#### `branch_gap4`

- Baseline runs: `0.27 0.28 0.27 0.27 0.27`
- Current runs: `0.21 0.22 0.22 0.22 0.21`
- Baseline mean: `0.272s`
- Current mean: `0.216s`
- Relative change: `+20.6%`

#### `csel`

- Baseline runs: `0.16 0.16 0.16 0.16 0.17`
- Current runs: `0.17 0.17 0.17 0.17 0.17`
- Baseline mean: `0.162s`
- Current mean: `0.170s`
- Relative change: `-4.9%`

### out_asm spot-check

- `cmp+b.cond` fused path still emits `lahf + seto + mov [env+rawflags] + jcc`
- no extra capture-path `push/pop` found around those sites

## 2026-03-19 Follow-up (seed `a64_flags_rep` from TB key)

This variant adds `x86_flags_valid` into A64 TB key bits and initializes
`a64_flags_rep` at TB entry from that value (`split/raw/status4`), to avoid
entry-side `unknown` fallback and redundant invalidation stores.

Correctness:

- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

### `/tmp/a64_cmpbench` (100000000 iterations)

#### `branch`

- Baseline runs: `0.21 0.20 0.20 0.20 0.21`
- Current runs: `0.14 0.14 0.14 0.14 0.14`
- Baseline mean: `0.204s`
- Current mean: `0.140s`
- Relative change: `+31.4%`

#### `branch_gap4`

- Baseline runs: `0.26 0.25 0.25 0.25 0.25`
- Current runs: `0.20 0.21 0.20 0.20 0.20`
- Baseline mean: `0.252s`
- Current mean: `0.202s`
- Relative change: `+19.8%`

#### `csel`

- Baseline runs: `0.15 0.15 0.15 0.15 0.15`
- Current runs: `0.16 0.16 0.16 0.16 0.16`
- Baseline mean: `0.150s`
- Current mean: `0.160s`
- Relative change: `-6.7%`

### IR spot-check

- in the hot TB at guest `0x400708`, the first `cmp` no longer emits
  `mov_i32 x86_flags_valid,$0x0`

## 2026-03-19 Optimization Step 1 (skip redundant RAW-valid write)

Change:

- In `a64_try_emit_x86_cmp_bcond`, emit
  `cpu_x86_flags_valid = A64_X86_FLAGS_RAW` only when
  `s->a64_flags_rep != A64_FLAGS_REP_RAW`.
- Keep `a64_note_flags_raw(s)` unchanged.

Correctness:

- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass
- `/tmp/a64_cmpbench` output equality pass

Perf (`/tmp/a64_cmpbench`, 100000000 iters):

- `branch`: baseline `0.20 0.20 0.20 0.20 0.20`,
  current `0.11 0.11 0.11 0.11 0.11` (mean `0.200s -> 0.110s`, `+45.0%`)
- `branch_gap4`: baseline `0.25 0.25 0.25 0.25 0.25`,
  current `0.16 0.16 0.16 0.16 0.16` (mean `0.250s -> 0.160s`, `+36.0%`)
- `csel`: baseline `0.15 0.15 0.15 0.15 0.15`,
  current `0.16 0.16 0.16 0.16 0.16` (mean `0.150s -> 0.160s`, `-6.7%`)

## 2026-03-19 Optimization Step 2 (restore split-flag direct condition path)

Change:

- In `a64_test_cc`, add a split-flags fast path:
  use `arm_test_cc` + `ext_i32_i64` directly, instead of first normalizing to
  bool via `a64_test_cc_bool_i32`.
- Keep non-split states (`raw/status4/unknown`) on the existing bool path.

Correctness:

- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass
- `/tmp/a64_cmpbench` output equality pass

Perf (`/tmp/a64_cmpbench`, 100000000 iters):

- `branch`: baseline `0.23 0.21 0.21 0.21 0.21`,
  current `0.11 0.11 0.11 0.11 0.11` (mean `0.214s -> 0.110s`, `+48.6%`)
- `branch_gap4`: baseline `0.26 0.26 0.26 0.27 0.26`,
  current `0.17 0.17 0.17 0.17 0.17` (mean `0.262s -> 0.170s`, `+35.1%`)
- `csel`: baseline `0.15 0.15 0.15 0.15 0.15`,
  current `0.16 0.15 0.16 0.15 0.15` (mean `0.150s -> 0.154s`, `-2.7%`)

IR spot-check:

- hot `csel` TB at guest `0x40070c` is now back to
  `ext_i32_i64 ..., ZF` + `movcond ... eq` (no extra `setcond_i32` boolization).

## 2026-03-19 Optimization Step 3 (conservative no-capture window for `cmp+b.cond`)

Change:

- Add a conservative skip-capture window in `a64_try_emit_x86_cmp_bcond`:
  when both successors' first instruction are guaranteed NZCV-overwriters
  (`ADDS/SUBS immediate`), emit non-capture x86 cmp+branch and avoid RAW flags save.
- Keep capture path as default fallback for all other cases.

Correctness:

- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Perf:

- On existing `/tmp/a64_cmpbench` (`branch/branch_gap4/csel`, 100000000 iters),
  this step is mostly neutral (those loops largely do not hit the skip window):
  - `branch`: `0.11s`
  - `branch_gap4`: `0.16s`
  - `csel`: `0.16s`
- On a targeted window-hit microbench (`/tmp/a64_windowbench`, 400000000 iters):
  - window enabled: `0.64 0.64 0.64 0.64 0.64`
  - force capture (A/B control): `0.76 0.77 0.76 0.76 0.76`
  - mean improvement: about `+15.8%`

## 2026-03-20 Direction Reset (raw-only canonical focus)

Real workload data so far indicates the current branch-local wins are not
enough to beat the global state-management overhead on SPEC-like programs.

Working conclusion:

- Keep `x86_raw_flags + x86_cc_op` as the primary canonical x86-derived state
- Prefer expanding raw-flags consumers over adding more producer-side state
- Treat split `NF/ZF/CF/VF` as a fallback / reconstruction target
- Re-evaluate `STATUS4` and TB-key coupling only after raw-consumer coverage is
  substantially broader

Next implementation focus:

- remove unnecessary `a64_ensure_split_flags()` use from partial-NZCV writers
  and other consumers that can directly read canonical raw flags

## 2026-03-20 Raw-Consumer Step 1 (partial-NZCV writers stop forcing split)

Change:

- Add `a64_get_current_nzcv_bits()` and `a64_write_split_flags_from_bits()` in
  `translate-a64.c` so A64 consumers can read canonical NZCV bits directly from
  `raw/status4/split/unknown` state without first materializing split flags.
- Rework these instructions to consume canonical bits directly:
  - `CFINV`
  - `RMIF`
  - `XAFLAG`
  - `AXFLAG`
- Remove now-dead `a64_ensure_split_flags()` and split-materialization helpers,
  because this first raw-consumer pass eliminated their remaining callers.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `ninja -C build qemu-system-aarch64` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Coverage:

- add `0x7a` / `0x7b` to `tests/tcg/aarch64/nzcv-status4.S`
  for `CMP -> XAFLAG/AXFLAG -> ADC`

Perf:

- not measured yet for this step; this patch is the first consumer-coverage
  expansion for the new raw-only canonical direction

## 2026-03-20 Raw-Consumer Step 2 (direct compare-form consumers for raw/state4)

Change:

- Add direct `DisasCompare64` builders for canonical flag states:
  - `a64_test_cc_rawflags_cmp()`
  - `a64_test_cc_status4_cmp()`
- Update `a64_test_cc()` so `RAW` and `STATUS4` no longer have to go through
  `a64_test_cc_bool_i32()` first; instead they return a direct
  `cond + value-vs-zero` form suitable for:
  - `CSEL/CSET/CSETM/CSINC/CSINV/CSNEG`
  - `FCSEL`
- Update `a64_gen_test_cc()` to branch from `a64_test_cc()` directly, so
  `FCCMP/FCCMPE` also benefit from the same direct consumer path.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `ninja -C build qemu-system-aarch64` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Coverage:

- add `0x7c` / `0x7d` / `0x7e` to `tests/tcg/aarch64/nzcv-status4.S`
  for:
  - `CMP + B.eq fallthrough -> CSEL(hi)`
  - `CMP + B.eq fallthrough -> FCSEL(gt)`
  - `CMP + B.eq fallthrough -> FCCMP(gt)`

Perf:

- not measured yet for this step; this patch broadens direct raw-consumer use
  for composite conditions without changing producer-side behavior

## 2026-03-20 Raw-Consumer Step 3 (bool consumers now reuse compare-form path)

Change:

- Add `a64_test_cc_cmp_to_bool_i32()`.
- Rework `a64_test_cc_bool_i32()` so `RAW` / `STATUS4` / runtime
  `raw|status4` cases no longer use the old eager bit-decoder path; they now:
  1. build direct `cond + value-vs-zero` compare form
  2. turn that into a bool only at the last step
- This lets bool consumers such as `CCMP/CCMN` reuse the same narrower
  raw-consumer logic instead of always extracting all four flag bits up front.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `ninja -C build qemu-system-aarch64` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Coverage:

- covered by the expanded raw-consumer tests added in Step 2 plus the existing
  `CCMP/CCMN` / `CSEL` / `FCSEL` cases in `nzcv-status4.S`

Perf:

- not measured yet for this step; this patch mainly removes duplicated
  condition-decoding work on bool-based consumers

## 2026-03-20 Raw-Consumer Step 4 (carry consumers stop pre-writing `cpu_CF`)

Change:

- Replace `a64_ensure_carry_flag()` with `a64_get_current_carry_flag()`, which
  extracts the architectural carry bit from the current canonical state into a
  temporary instead of eagerly writing `cpu_CF`.
- Rework:
  - `ADC/SBC/ADCS/SBCS`
  - `SETF8/SETF16`
  so they consume carry through a local temp and only write split flags at the
  final point where architectural state must actually change.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `ninja -C build qemu-system-aarch64` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Coverage:

- add `0x7f` to `tests/tcg/aarch64/nzcv-status4.S`
  for `CMP + B.eq fallthrough -> SETF8`

Perf:

- targeted `/tmp/a64_cmpbench` rerun was not available in this session because
  the benchmark binary was absent from `/tmp`

## 2026-03-20 Raw-Producer Step 5 (explicit NZCV writers now keep RAW canonical)

Change:

- Add `a64_write_raw_flags_from_bits()` to encode arbitrary ARM `NZCV` into a
  synthetic compare/sub-style `raw_flags` layout.
- Rework these producer-side flag writers to use the synthetic raw encoding
  instead of falling back to split flags:
  - `CFINV`
  - `RMIF`
  - `XAFLAG`
  - `AXFLAG`
  - `gen_set_nzcv()` callers (`MSR NZCV`, `FCMP`, `FCCMP` false-literal path)
  - `SETF8/SETF16`

Why:

- Before this step, these instructions could read the current canonical state
  cheaply but would immediately force a split-flags materialization when they
  wrote flags back.
- After this step, the canonical state stays in `RAW` for more producer chains,
  so later consumers still have a chance to use the raw fast path.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `ninja -C build qemu-system-aarch64` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Coverage:

- existing `nzcv-status4.S` cases covering `MSR NZCV`, `RMIF`, `CFINV`,
  `XAFLAG`, `AXFLAG`, `SETF8/SETF16`, `FCMP`, and `FCCMP` continue to pass
  under the new synthetic-raw producer behavior

Perf:

- not measured yet for this step; this patch is aimed at preserving raw
  canonical state longer rather than changing branch emission directly

## 2026-03-20 Raw-Producer Step 6 (CCMP/CCMN now keep RAW canonical)

Change:

- Add local `N/Z/C/V` bit calculators for add/sub compare results:
  - `a64_gen_add_nzcv_bits()`
  - `a64_gen_sub_nzcv_bits()`
- Rework `trans_CCMP()` so it no longer materializes split flags via
  `gen_add_CC()` / `gen_sub_CC()` just to patch them afterward.
- The new flow is:
  1. compute add/sub result bits into local temps
  2. select between computed bits and literal `nzcv` depending on `COND`
  3. write the final result back through `a64_write_raw_flags_from_bits()`

Why:

- Before this step, `CCMP/CCMN` broke the raw canonical chain even when both
  their input condition consumption and their downstream consumers could
  already operate on raw.
- After this step, `CCMP/CCMN` can themselves serve as raw producers for later
  `ADC/SBC`, `CSEL/FCSEL`, and `MRS NZCV`.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `ninja -C build qemu-system-aarch64` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Coverage:

- add `0x80` / `0x81` to `tests/tcg/aarch64/nzcv-status4.S`
  for:
  - `CCMP true -> ADC`
  - `CCMN false literal -> ADC`
- existing `CCMP/CCMN -> CSEL/MRS NZCV` coverage continues to pass

Perf:

- not measured yet for this step; this patch focuses on keeping `CCMP/CCMN`
  inside the raw canonical pipeline

## 2026-03-20 Raw-Producer Step 7 (logical flags writers now keep RAW canonical)

Change:

- Rework `gen_logic_CC()` so `ANDS/TST/BICS`-style logical flag writers no
  longer materialize split flags.
- The new flow is:
  1. derive `N/Z` directly from the logical result
  2. set `C=0`, `V=0`
  3. write the final state via `a64_write_raw_flags_from_bits()`

Why:

- Logical flag writers are common producer sites, and previously they always
  broke the raw canonical chain even when downstream consumers were already
  able to operate on raw.
- After this step, logical producers can feed later `B.cond`, `CSEL/FCSEL`,
  `ADC/SBC`, and `MRS NZCV` without first falling back to split flags.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `ninja -C build qemu-system-aarch64` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Coverage:

- add `0x82` to `tests/tcg/aarch64/nzcv-status4.S`
  for `TST -> ADC`
- existing `ANDS/TST -> B.eq/CSEL` coverage continues to pass

Perf:

- not measured yet for this step; this patch expands raw producer coverage on
  logical flag-setting instructions

## 2026-03-20 Raw-Producer Step 8 (generic arithmetic flags writers now keep RAW canonical)

Change:

- Rework the common arithmetic flag writers:
  - `gen_add_CC()`
  - `gen_sub_CC()`
  - `gen_adc_CC()`
- They no longer materialize split flags. Instead they:
  1. compute result plus local `N/Z/C/V` bits
  2. write the final architectural state via `a64_write_raw_flags_from_bits()`

Why:

- These helpers sit underneath the most common flag-producing A64 integer
  instructions, so keeping them in raw canonical form widens producer coverage
  much more than one-off instruction tweaks.
- After this step, `ADDS/SUBS`, `CMN/CMP` normal flag paths, and `ADCS/SBCS`
  all keep the canonical state in `RAW`.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `ninja -C build qemu-system-aarch64` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Coverage:

- add `0x83` / `0x84` to `tests/tcg/aarch64/nzcv-status4.S`
  for:
  - `ADCS -> ADC`
  - `SBCS -> ADC`
- existing `ADDS/CMN -> branch/CSEL/ADC` coverage continues to pass

Perf:

- not measured yet for this step; this patch is aimed at expanding raw
  canonical coverage across the common arithmetic producer path

## 2026-03-20 State-Machine Step 9 (collapse STATUS4 out of translation)

Change:

- Confirm there are no active STATUS4 producers left in the current codebase.
- Stop feeding `STATUS4` into the TB entry path:
  - `hflags` now only distinguishes `RAW` vs non-`RAW`
  - TB init maps the flags representation to `RAW` or `SPLIT`
- Remove `STATUS4` handling from the remaining translation-side dispatch:
  - `UNKNOWN` runtime branches now only test `RAW` vs split fallback
  - delete translation-only `STATUS4` helpers and decode paths
  - drop the `cpu_x86_status4` TCG global

Why:

- At this point `STATUS4` had become a dead translation-time branch: it was
  still adding decode and dispatch cost, but no longer had live producers.
- Collapsing the translation state machine reduces TB-entry variation and trims
  consumer-side runtime branching without changing the active RAW/SPLIT logic.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `ninja -C build qemu-system-aarch64` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Residuals:

- none in active code paths after the follow-up legacy-state cleanup

Follow-up:

- remove `CPUARMState.x86_status4`
- remove `A64_X86_FLAGS_STATUS4`
- remove reset/init zeroing of the legacy field

This follow-up has now been completed in the current tree.

Perf:

- not measured yet for this step; this patch targets translation-state
  simplification rather than adding new producer/consumer direct paths

## 2026-03-20 State-Machine Step 10 (remove STATUS4 legacy state)

Change:

- Delete the remaining legacy `STATUS4` CPU state:
  - remove `CPUARMState.x86_status4`
  - remove `A64_X86_FLAGS_STATUS4`
  - remove the associated reset/init clearing
- After this step, `X86_FLAGS_VALID` is effectively a 2-state marker:
  - `INVALID`
  - `RAW`

Why:

- The previous step had already removed `STATUS4` from all active translation
  paths, so keeping the legacy field and enum only added structure and
  maintenance overhead.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `ninja -C build qemu-system-aarch64` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Perf:

- not measured yet for this step; this is a final state-model cleanup

## 2026-03-20 Host-Direct Step 11 (fix raw capture modelling; extend ANDS/ADC/SBC direct path)

Change:

- Fix mid-block raw capture so the optimizer sees an explicit TCG def of
  `cpu_x86_raw_flags`, instead of an opaque env-side-effect write.
- Re-enable the logical-raw path with a dedicated `x86_and_capture_rawflags`
  backend op, currently used by `gen_logic_CC()`.
- Switch plain `ADC/SBC` (non-flags-setting) to use the host `adc` carry
  chain on x86 as well.

Why:

- The previous `x86_capture_rawflags` form was correctness-critical:
  later raw consumers in the same TB could still read the old constant value.
- Once capture is modelled as a real def-use edge, same-TB raw consumers
  (`ADC`, `MRS NZCV`, conditional consumers) can safely reuse canonical raw.
- Extending plain `ADC/SBC` to the host carry chain reduces the remaining gap
  between flags-setting and non-flags-setting arithmetic carry consumers.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `ninja -C build qemu-system-aarch64` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Notes:

- This step fixes the earlier `0x88` failure (`ADCS32 -> ADC -> MRS NZCV`).
- `ANDS` now emits visible host `and` + `lahf/seto` in `out_asm` again.

Perf:

- not measured yet for this step; priority here was restoring same-TB raw
  correctness so later perf work has a sound base

## 2026-03-20 Host-Direct Step 12 (fuse ANDS/BICS/TST reg-form producers)

Change:

- Fuse `ANDS/BICS` register-form producers so the host `and` that computes the
  guest result also produces canonical raw flags in the same operation path.
- Add direct `TST` register-form handling via host `test`.
- Keep logical-immediate forms on the conservative path for now.
- Add UT `0x89` to cover `BICS -> ADC`.

Why:

- The previous logical path was already correct, but it still had an extra
  post-result capture step.
- Fusing the register-form producer removes that extra logical replay and gets
  closer to the intended “one host instruction computes both result and flags”
  design point.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Notes:

- `out_asm` now shows fused host `and`/`test` + `lahf/seto` for logical
  reg-form producers/consumers.

Perf:

- not measured yet for this step

## 2026-03-30 Host-Direct Step 21 (narrow immediate-form direct scope: drop `CMN32 #imm -> ADC32`)

Change:

- Keep the immediate-form direct-consumer work for:
  - `CMN64 #imm -> ADC64`
  - `CMP #imm -> SBC`
  - `ADDS rd,#imm -> ADC`
  - `SUBS rd,#imm -> SBC`
- Narrow the compare-like add side so `CMN32/ADDS xzr,#imm -> ADC32` no longer
  records `lazy_adc_add` and therefore no longer demands a host-direct shape.
- Keep the 32-bit guest case in `adc-sbc-host-direct.S` as a semantics smoke
  case, but remove the corresponding codegen hard assertion from
  `check-adc-sbc-host-direct.sh`.

Why:

- Full-scope immediate A/B showed only one stable negative outlier:
  `cmnadc32_imm`.
- That path was paying too much i32 raw-flags glue compared with the carry
  decode it removed, while the rest of the immediate-form matrix stayed
  positive or neutral.
- Narrowing only this one case keeps the rest of the gains without dragging in
  a still-unprofitable i32 compare-like immediate add path.

Implementation:

- In `do_addsub_imm()`, compare-like immediate add now enables `lazy_adc_add`
  only when `a->sf` is true.
- No consumer-side logic was widened or special-cased further; the narrowing is
  entirely producer-side.
- Focused codegen guard now intentionally does not require direct host `addl`
  + `adcl` for `cmn-imm->adc32`.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ... adc-sbc-host-direct` pass
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu .../nzcv-status4`
  pass
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu .../cmpstress-o3`
  pass
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`
  pass

Perf:

- same tree
- same binary
- add-side 只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`
- benchmark:
  - `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`

`200000000` iterations:

- `cmnadc64_imm`
  - 开启：`0.33 0.34 0.33`
  - 关闭：`0.36 0.38 0.37`
  - median：`0.33` vs `0.37`
  - 开启 direct 快约 `10.8%`
- `cmnadc32_imm`
  - 开启：`0.35 0.35 0.35`
  - 关闭：`0.35 0.34 0.34`
  - median：`0.35` vs `0.34`
  - 已回到同量级，不再出现收窄前 `15%+` 的稳定负回退

`400000000` iterations spot-check:

- `cmnadc64_imm`
  - 开启：`0.65 0.65`
  - 关闭：`0.72 0.74`
- `cmnadc32_imm`
  - 开启：`0.71 0.71`
  - 关闭：`0.69 0.68`
  - 这组已退回同档位波动区，说明收窄后不再存在原先那种明显 code-shape
    级回退

Conclusion:

- 这次收窄不是撤销整步 immediate 优化，而是有意识地排除
  `CMN32 #imm -> ADC32` 这一条当前不划算的 compare-like add path。
- 收窄后，其余 immediate direct-consumer 路径继续保留；focused correctness
  全绿。
- `cmnadc64_imm` 继续稳定正收益，`cmnadc32_imm` 不再是 perf hard gate 的
  blocker。

## 2026-03-30 Host-Direct Step 17 补充（`cmnadc32` root cause 与 i32 backend 收口）

变更：

- 为 `CMN / ADDS xzr -> ADC32` 新增单独的 i32 host opcode：
  `x86_add_adc_capture_add_rawflags_i32`
- 这个 opcode 固定把输出放在 `EAX`，使 `lahf/seto` 可以直接复用
  `EAX`，不再为保护 `RAX` 额外发 `pushq/popq`
- `ADC64` 继续沿用原来的通用 opcode，不改已经稳定正收益的 64-bit 路径
- `adc-sbc-host-direct` 新增 `w32 cmn->adc` codegen 回归，并要求
  `addl` 与 `adcl` 之间不再夹 `push/pop`

原因：

- dedicated `cmnadc32` A/B 已证明“打中了 direct path 但仍然负收益”
- 进一步对齐 loop `out_asm` 后确认，旧的 i32 fused path 在
  `addl` 与 `adcl` 之间还要做一次 `pushq/lahf/seto/mov/popq`
- 这部分保存 rawflags 的胶水成本，抵消了 32-bit direct consumer
  删掉 carry decode 本来该拿到的收益

正确性：

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ... adc-sbc-host-direct` pass
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`
  pass
- `nzcv-status4` pass
- `cmpstress-o3` pass

性能：

- same-binary A/B，命中 dedicated `cmnadc` mode，只切
  `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`
- `200000000` iterations，交错顺序复测

- `cmnadc32`
  - 开启 direct：`0.44 0.41 0.40`
  - 关闭 direct：`0.45 0.45 0.46`
  - median `0.41` vs `0.45`
  - 开启 direct 快约 `8.9%`

- `cmnadc64`
  - 开启 direct：`0.32 0.32 0.33`
  - 关闭 direct：`0.41 0.43 0.42`
  - median `0.32` vs `0.42`
  - 开启 direct 快约 `23.8%`

## 2026-03-30 Host-Direct Step 17（same-TB adjacent `CMN / ADDS xzr -> plain ADC`）

变更：

- 新增 same-TB adjacent `CMN / ADDS xzr -> plain ADC` 的 direct-consumer fast
  path。
- A64 前端只在最窄 scope 内命中：
  - producer：register-form `CMN / ADDS xzr`
  - consumer：紧邻的 plain register `ADC`
- i386 后端新增 fused op：
  - 先做 producer `add`
  - capture add rawflags
  - 再直接做 consumer `adc`
- 增加窄开关：
  - `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`

正确性：

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `run-adc-sbc-host-direct-codegen` 通过
- `run-nzcv-status4` 通过
- `run-cmpstress-o3` 通过
- `adcsbc-bench` 运行通过

补充覆盖：

- `adc-sbc-host-direct.S`
  - 新增真正相邻的 `CMN -> ADC` codegen 检查
- `nzcv-status4.S`
  - 新增 `0x94`：adjacent `CMN64 -> ADC`
  - 新增 `0x95`：adjacent `CMN32 -> ADC`

实现过程里暴露出的两个真实问题：

- 第一处是测试本身写偏了：
  - 最初的 `CMN` 和 `ADC` 中间夹了两条 `mov`
  - 这不属于 phase-1 的 adjacent scope
  - 修正后才真正打到新路径
- 第二处是 fused op 的寄存器分配 bug：
  - `dst` 被当 scratch 做 producer `add`
  - 但旧约束允许 `dst` 和 `adc_lhs` 分到同一个寄存器
  - 结果先把 `adc_lhs` 踩掉，再执行 `adc`
  - 修复方式是把这条 op 改成 early-clobber / new-register 约束
    `C_N1_I4(...)`

`out_asm` 现在的目标形态：

- `CMN -> ADC` block 收成：
  - `add`
  - `lahf`
  - `seto`
  - `adc`
- 旧的 carry decode 链不再出现在这个 block：
  - `shr`
  - `and`
  - `setcc`

### 2026-03-30 Step 17 的第一次 isolated A/B 备注

方法：

- 同一棵树、同一二进制
- 默认开启 step 17
- 关闭方式：
  - `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`
- benchmark：
  - `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`
- iterations：
  - `200000000`

结果摘要：

- `adc64`
  - 开启：`0.45 0.45 0.45 0.45 0.45`
  - 关闭：`0.46 0.46 0.46 0.45 0.45`
  - median：`0.45` vs `0.46`
- `adcsbc64`
  - 开启：`0.53 0.52 0.53 0.54 0.53`
  - 关闭：`0.53 0.56 0.53 -1.96 0.52`
  - median：`0.53` vs `0.53`
  - 关闭侧出现 1 次异常值，不纳入结论
- `adc32`
  - 开启：`0.48 0.49 0.49 0.48 0.50`
  - 关闭：`0.49 0.50 0.49 0.48 0.49`
  - median：`0.49` vs `0.49`
- `adcsbc32`
  - 开启：`0.65 0.64 0.64 0.65 0.65`
  - 关闭：`0.65 0.64 0.65 0.64 0.65`
  - median：`0.65` vs `0.65`
- control `sbc64`
  - 开启：`0.36 0.36 0.38 0.38 0.38`
  - 关闭：`0.37 0.36 0.38 0.38 0.38`
  - median：`0.38` vs `0.38`

解释：

- 这组数字基本持平，但**不能**据此判断 step 17 “没有收益”。
- 原因是当前 `adcsbc-bench` 里的这些模式并不覆盖新路径：
  - `adc64` / `adc32` 用的是 `CMP -> ADC`
  - `adcsbc64` / `adcsbc32` 里的 `ADC` producer 也仍然是 `CMP`
- 而 step 17 的命中条件是：
  - `CMN / ADDS xzr -> plain ADC`
- 所以这轮 A/B 的真实含义是：
  - 现有 microbenchmark 没测中目标路径
  - 需要单独补 `CMN->ADC` benchmark mode，再做一次 isolated A/B

### 2026-03-30 Step 17 的第二次 isolated A/B（dedicated `cmnadc` modes）

为真正命中这一步，我先扩了 benchmark：

- `adcsbc-bench` 新增：
  - `cmnadc64`
  - `cmnadc32`
- 默认输出和 `adcsbc-bench.out` 也同步更新，保证这两个 mode 有固定回归

正确性：

- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench` 通过
- `cmnadc64 4096` 输出：
  - `adcsbc-bench cmnadc64 0x0b88090d94917853`
- `cmnadc32 4096` 输出：
  - `adcsbc-bench cmnadc32 0x82038df6762e5172`

Method：

- same tree
- same binary
- 只切：
  - `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`
- benchmark：
  - `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`

#### 第一轮：`200000000` iterations

- `cmnadc64`
  - 开启：`0.36 0.33 0.32 0.33 0.32`
  - 关闭：`0.41 0.43 0.43 0.41 0.42`
  - mean / median：
    - 开启 `0.332 / 0.330`
    - 关闭 `0.420 / 0.420`
  - 开启 direct 快约 `21.4%`

- `cmnadc32`
  - 开启：`0.48 0.49 0.48 0.48 0.50`
  - 关闭：`0.45 0.46 0.44 0.45 -1.81`
  - 关闭侧出现一次异常值
  - median：
    - 开启 `0.48`
    - 关闭 `0.45`
  - 初看是开启 direct 略慢

- control `adc64`
  - 开启：`0.45 0.45 0.45 0.45 0.46`
  - 关闭：`0.46 0.45 0.45 0.46 0.46`
  - median：`0.45` vs `0.46`

- control `adc32`
  - 开启：`0.50 0.48 0.50 0.49 0.48`
  - 关闭：`0.48 0.49 0.49 0.49 0.49`
  - median：`0.49` vs `0.49`

- control `sbc64`
  - 开启：`0.37 0.36 0.37 0.37 0.38`
  - 关闭：`0.37 0.36 0.36 0.36 0.37`
  - median：`0.37` vs `0.36`

#### 第二轮确认：交错顺序、`400000000` iterations

- `cmnadc64`
  - 开启：`0.68 0.66 0.65`
  - 关闭：`0.83 0.83 0.83`
  - 64-bit 结果稳定，开启 direct 继续明显更快

- `cmnadc32`
  - 开启：`0.99 0.98 0.98`
  - 关闭：`0.88 0.91 0.89`
  - 32-bit 结果也稳定，当前实现下开启 direct 仍然更慢

Spot-check：

- `cmnadc32` 的 32-bit direct path 已经真实命中
- `out_asm` 里能看到：
  - `addl`
  - `adcl`
- 所以 32-bit 不是“没打中新路径”，而是“当前 i32 实现命中了但收益不够”

当前结论：

- step 17 在 **64-bit `CMN->ADC`** 上已经证明是正收益
- 但在 **32-bit `CMN->ADC`** 上，当前实现仍然是负收益
- 因此这一步现在还**不能**像 step 16 那样下“全量正收益”的结论
- 下一步应该聚焦：
  - 继续优化 i32 fused path 的寄存器/胶水开销
  - 然后再重新做 dedicated `cmnadc32` A/B

## 2026-03-30 Host-Direct Step 18（same-TB adjacent `ADDS rd -> plain ADC`）

这一步继续沿用 `1.5` 路线：

- producer 侧不做 defer，`ADDS rd` 继续走现有 direct `gen_add_CC(..., allow_direct = true)`
- 只额外记录一位最小 metadata：
  - `a64_cmp_pending_materialized = true`
- consumer 侧命中相邻 plain `ADC` 时：
  - 不再重做 producer `add`
  - 直接复用 `INDEX_op_addci`
  - 吃 live host `CF`
- consumer 后 guest 可见 NZCV 仍然保持 producer raw flags

### fresh correctness

- codegen 回归补了两组：
  - `ADDS64 rd -> ADC`
  - `ADDS32 rd -> ADC`
- `nzcv-status4` 补了两条语义 guard：
  - `0x96`：adjacent `ADDS64 rd + plain ADC`
  - `0x97`：adjacent `ADDS32 rd + plain ADC`
- fresh 验证：
  - `ninja -C build-aarch64-linux-user qemu-aarch64`
  - `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ... adc-sbc-host-direct`
  - `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`
  - `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`
  - `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`

### dedicated benchmark 扩展

为了真正命中这一步，`adcsbc-bench` 新增：

- `addsadc64`
- `addsadc32`

golden hash：

- `addsadc64 4096`
  - `adcsbc-bench addsadc64 0x71aa68192aeb1bd2`
- `addsadc32 4096`
  - `adcsbc-bench addsadc32 0x79399d9e4be66630`

### isolated A/B

Method：

- same tree
- same binary
- 只切：
  - `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`
- benchmark：
  - `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`
- iterations：
  - `200000000`

结果：

- `addsadc64`
  - 开启：`0.33 0.34 0.32`
  - 关闭：`0.42 0.41 0.42`
  - median：`0.33` vs `0.42`
  - 开启 direct 快约 `21.4%`

- `addsadc32`
  - 开启：`0.41 0.42 0.42`
  - 关闭：`0.51 0.50 0.50`
  - median：`0.42` vs `0.50`
  - 开启 direct 快约 `16.0%`

- control `cmnadc64`
  - 开启：`0.34 0.34 0.33`
  - 关闭：`0.41 0.43 0.42`
  - median：`0.34` vs `0.42`
  - phase-1 路径保持正收益

- control `cmnadc32`
  - 开启：`0.40 0.41 0.43`
  - 关闭：`0.45 0.45 0.45`
  - median：`0.41` vs `0.45`
  - phase-1 路径保持正收益

- control `adc64`
  - 开启：`0.46 0.45 0.46`
  - 关闭：`0.45 0.46 0.45`
  - median：`0.46` vs `0.45`
  - 基本持平，属于噪音范围

- control `adc32`
  - 开启：`0.49 0.50 0.49`
  - 关闭：`0.51 0.50 0.48`
  - median：`0.49` vs `0.50`
  - 基本持平

### 当前结论

- same-TB adjacent `ADDS64 rd -> plain ADC`：正收益，结论稳定
- same-TB adjacent `ADDS32 rd -> plain ADC`：正收益，结论稳定
- 这说明 step 18 本身已经证明是正收益，不是全局拖慢来源
- 同时 phase-1 的 `CMN / ADDS xzr -> ADC` control 也维持正收益，没有被这次扩展拖坏

### 2026-03-30 fresh SPEC correctness

为了确认 step 18 没有把真实 workload 的 correctness 基线打坏，
我又 fresh 复跑了一轮当前跟踪的 SPEC train 子集：

- 先执行：
  - `ninja -C build-aarch64-linux-user qemu-aarch64`
- 然后在当前树上重跑：
  - `500.perlbench_r train`
  - `502.gcc_r train`
  - `531.deepsjeng_r train`
  - `557.xz_r train`

结果：

- `531.deepsjeng_r train`
  - `specinvoke -f speccmds.cmd`：`rc=0`
  - `specinvoke -f compare.cmd`：`rc=0`
  - 输出 [train.out](/home/wangruoyu/cpuspec2017/benchspec/CPU/531.deepsjeng_r/run/run_base_train_mytest-64.0000/train.out)
    与参考
    [train.out](/home/wangruoyu/cpuspec2017/benchspec/CPU/531.deepsjeng_r/data/train/output/train.out)
    行数一致：`579 == 579`

- `502.gcc_r train`
  - `specinvoke -f speccmds.cmd`：`rc=0`
  - `specinvoke -f compare.cmd`：`rc=0`
  - 三个 `.s` 输出的 `specdiff` 都是 `rc=0`

- `557.xz_r train`
  - `specinvoke -f speccmds.cmd`：`rc=0`
  - `specinvoke -f compare.cmd`：`rc=0`
  - `IMG_2560.cr2-40-4.out` / `input.combined-40-8.out` 的 `specdiff`
    都是 `rc=0`

- `500.perlbench_r train`
  - `run_base_train_mytest-64.0000`：`specinvoke -f speccmds.cmd` `rc=0`
  - `run_base_train_mytest-64.0001`：`specinvoke -f speccmds.cmd` `rc=0`
  - `run_base_train_mytest-64.0001` 的 `compare.cmd`：`rc=0`
  - `run_base_train_mytest-64.0000` 目录里缺 `compare.cmd`，
    所以改用逐文件 `cmp -s` 手工比对：
    - `diffmail.2.550.15.24.23.100.out`
    - `perfect.b.3.out`
    - `scrabbl.out`
    - `splitmail.535.13.25.24.1091.1.out`
    - `suns.out`
    - `validate`
    - 结果全部一致

这说明在 fresh SPEC train 子集上，step 18 当前实现仍然保持 correctness 全绿。

## 2026-03-30 Host-Direct Step 19（same-TB adjacent `SUBS rd -> plain SBC`）

这一步沿用 step 18 的 `1.5` 骨架，但把 producer 从 `ADDS rd` 换成
`SUBS rd`：

- producer 侧不做 defer，`SUBS rd` 继续走现有 direct `gen_sub_CC(..., allow_direct = true)`
- 只额外记录：
  - 这条 pending producer 已经 materialize
  - 下一条相邻 plain `SBC` 可以直接消费 live host borrow
- consumer 侧命中相邻 plain `SBC` 时：
  - 不再从 canonical raw flags decode carry/borrow
  - 直接复用 host `sbb`
  - guest 可见 NZCV 仍然保持 producer raw flags

### fresh correctness

- codegen 回归补了两组：
  - `SUBS64 rd -> SBC`
  - `SUBS32 rd -> SBC`
- `nzcv-status4` 补了两条语义 guard：
  - `0x98`：adjacent `SUBS64 rd + plain SBC`
  - `0x99`：adjacent `SUBS32 rd + plain SBC`
- fresh 验证：
  - `ninja -C build-aarch64-linux-user qemu-aarch64`
  - `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ... adc-sbc-host-direct`
  - `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`
  - `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`
  - `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`

### dedicated benchmark 扩展

为了真正命中这一步，`adcsbc-bench` 新增：

- `subsbc64`
- `subsbc32`

golden hash：

- `subsbc64 4096`
  - `adcsbc-bench subsbc64 0xb87bc1bc406b2d11`
- `subsbc32 4096`
  - `adcsbc-bench subsbc32 0xdd06b595106b03a2`

### isolated A/B

Method：

- same tree
- same binary
- 只切：
  - `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1`
- benchmark：
  - `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`
- iterations：
  - `200000000`

结果：

- `subsbc64`
  - 开启：`0.39 0.37 0.38`
  - 关闭：`0.48 0.48 0.48`
  - median：`0.38` vs `0.48`
  - 开启 direct 快约 `20.8%`

- `subsbc32`
  - 开启：`0.54 0.54 0.53`
  - 关闭：`0.61 0.60 0.59`
  - median：`0.54` vs `0.60`
  - 开启 direct 快约 `10.0%`

- control `sbc64`
  - 开启：`0.41 0.41 0.40`
  - 关闭：`0.40 0.41 0.41`
  - median：`0.41` vs `0.41`
  - 基本持平

- control `sbc32`
  - 开启：`0.47 0.45 0.46`
  - 关闭：`0.46 0.47 0.46`
  - median：`0.46` vs `0.46`
  - 基本持平

### 当前结论

- same-TB adjacent `SUBS64 rd -> plain SBC`：正收益，结论稳定
- same-TB adjacent `SUBS32 rd -> plain SBC`：正收益，结论稳定
- 这说明 step 19 本身已经证明是正收益，不是全局拖慢来源
- 控制项 `sbc64/sbc32` 基本持平，说明差异确实对着新路径来的

## 2026-03-30 Host-Direct Step 20（pending-cc producer 轻量泛化）

这一步不新增任何新的 producer / consumer 直通命中。

目标是把当前 compare-centric 的 `a64_cmp_pending_*` translation metadata
收敛成统一的 `A64PendingCCProducer` 小结构，并把下列共享语义集中起来：

- clear / reset
- record / trace / drop
- adjacent-only 判定
- consumer 命中后的 canonical raw-state 恢复

### 变更

- 在 `translate.h` 中引入：
  - `A64PendingCCProducerKind`
  - `A64PendingCCProducer`
- 当前 3 类真实 producer 统一映射为：
  - `A64_PENDING_CC_REWINDABLE_CMP`
  - `A64_PENDING_CC_MATERIALIZED_ADD`
  - `A64_PENDING_CC_MATERIALIZED_SUB`
- `translate-a64.c` 中新增/收敛：
  - `a64_clear_pending_cc_producer()`
  - `a64_pending_cc_is_adjacent_to_curr_insn()`
  - `a64_pending_cc_has_live_split_flags()`
  - `a64_pending_cc_restore_raw_state_after_consume()`
- 删除 `DisasContext` 中散落的 `a64_cmp_pending_*` 字段，`pending_cc`
  成为唯一真源

### fresh correctness

- `ninja -C build-aarch64-linux-user qemu-aarch64`
- `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ... adc-sbc-host-direct`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu .../nzcv-status4`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu .../cmpstress-o3`
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`

结果：

- codegen 回归通过
- `nzcv-status4`：`PASS`
- `cmpstress-o3`：`cmpstress-o3 0x03c9d1a1e84724d4`
- `run-adcsbc-bench`：通过

### performance hard gate（same-binary spot-check）

方法：

- same tree
- same binary
- benchmark：
  - `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`
- iterations：
  - `200000000`
- add-side 只切：
  - `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`
- sub-side 只切：
  - `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1`

以中位数对比 baseline 与 refactor 后结果：

- `cmnadc64`
  - baseline：`0.34` vs `0.43`
  - refactor 后：`0.36` vs `0.42`
- `cmnadc32`
  - baseline：`3.15` vs `3.18`
  - refactor 后：`3.17` vs `3.18`
  - 这一项机器噪音较大，但中位数与 baseline 同量级
- `addsadc64`
  - baseline：`0.35` vs `0.42`
  - refactor 后：`0.35` vs `0.42`
- `addsadc32`
  - baseline：`0.47` vs `0.50`
  - refactor 后：`0.42` vs `0.50`
- `subsbc64`
  - baseline：`0.38` vs `0.46`
  - refactor 后：`0.35` vs `0.46`
- `subsbc32`
  - baseline：`0.51` vs `0.55`
  - refactor 后：`0.50` vs `0.54`

### 当前结论

- 这一步是结构整理，不是新优化项
- focused correctness 保持全绿
- six-mode same-binary spot-check 未出现超出噪音的稳定负回退
- 因此 step 20 可收；后续继续扩新直通时，可以直接复用统一的
  `pending_cc.kind + cc_op + rewind` metadata

## 2026-03-28 Host-Direct Step 16 (same-TB adjacent `CMP/SUBS(xzr)` -> plain `SBC` direct consumer)

Change:

- Add a narrow direct-consumer fast path for same-TB adjacent compare-like
  producers followed by plain register-form `SBC`.
- Producer side records pending compare only for:
  - `SUBS xzr, rn, rm` / `CMP rn, rm`
  - next instruction exactly `SBC`
- Consumer side emits a dedicated x86 sequence via
  `x86_cmp_sbb_capture_cmp_rawflags`.
- Add UT `0x93` to `nzcv-status4` to assert plain `SBC` keeps the original
  compare `NZCV`.

Why:

- The previous plain `SBC` path still paid the expensive carry decode chain:
  canonical raw -> carry bit -> borrow seed -> `sbb`.
- A fully capture-free `cmp; sbb` is not correct for plain `SBC`, because
  plain `SBC` must preserve the original guest flags.
- This step therefore uses:
  - `cmp`
  - capture compare rawflags
  - `sbb`
- That keeps guest `NZCV` correct while removing the decode path.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `run-adc-sbc-host-direct-codegen` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass
- `adcsbc-bench` runtime pass

Notes:

- The first implementation had one real bug in TCG dispatch:
  - the new op consumed the tied old-dst as `src`
  - this produced wrong `cmp/sbb` operands
  - fixed by correcting the argument remap in `tcg/tcg.c`
- `out_asm` for the adjacent `cmp x5, x5; sbc x8, x5, x6` block now shows:
  - `cmpq %rbx, %rbx`
  - `lahf`
  - `seto %al`
  - `sbbq %r13, %r12`
- The old `shr/and/xor/sub` carry decode chain is gone from that block.

Perf:

- not measured yet for this step in isolation
- this step should be evaluated as:
  - current tree with step 16
  - vs current tree with step 16 disabled
- comparing against `qemu10.2_clean` alone would mix in the cost of the whole
  experimental branch

### 2026-03-28 Isolated A/B for Step 16 (`QEMU_A64_DISABLE_CMP_SBC_DIRECT`)

Method:

- same binary, same tree
- compare:
  - default: step 16 enabled
  - `QEMU_A64_DISABLE_CMP_SBC_DIRECT=1`: step 16 disabled
- benchmark:
  - `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`
- iterations:
  - `200000000`

Results:

- `sbc64`
  - with direct: `0.41 0.41 0.48 0.51 0.50`
  - without direct: `0.55 0.52 0.51 0.52 0.51`
  - median: `0.48` vs `0.52`
  - step 16 faster by about `7.7%`

- `adcsbc64`
  - with direct: `0.53 0.53 0.54 0.53 0.56`
  - without direct: `0.59 0.59 0.60 0.60` plus one anomalous outlier
  - median: `0.53` vs `0.59`
  - step 16 faster by about `10.2%`

- `sbc32`
  - with direct: `0.42 0.43 0.42 0.42 0.41`
  - without direct: `0.53 0.53 0.54 0.53 0.55`
  - median: `0.42` vs `0.53`
  - step 16 faster by about `20.8%`

- control `adc64`
  - with direct: `0.46 0.46 0.46`
  - without direct: `0.46 0.46 0.46`
  - effectively unchanged

Interpretation:

- This step is locally net-positive.
- The improvement is where it should be:
  - `SBC`-heavy modes improve
  - mixed `ADCSBC` also improves
  - unrelated `ADC` control is flat
- Therefore the earlier “current tree vs clean tree is still slower” result is
  not caused by this step. The remaining regression budget is elsewhere in the
  experimental branch.

## 2026-03-28 Follow-up Microbenchmark (`adcsbc-bench`, current vs clean)

Setup:

- Benchmark binary:
  `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`
- Iterations:
  `200000000`
- Repetitions:
  `5`
- Baseline:
  `/home/wangruoyu/qemu10.2_clean/build-aarch64-linux-user/qemu-aarch64`
- Current:
  `/home/wangruoyu/qemu10.2/build-aarch64-linux-user/qemu-aarch64`

### `adc64`

- Baseline runs: `0.426 0.415 0.430 0.428 0.439`
- Current runs: `0.484 0.471 0.491 0.475 0.473`
- Baseline mean/median: `0.428 / 0.428`
- Current mean/median: `0.479 / 0.475`
- Relative change: `0.894x` (`current` slower by `11.9%`)

### `sbc64`

- Baseline runs: `0.461 0.444 0.455 0.450 0.467`
- Current runs: `0.522 0.513 0.513 0.509 0.524`
- Baseline mean/median: `0.455 / 0.455`
- Current mean/median: `0.516 / 0.513`
- Relative change: `0.881x` (`current` slower by `13.4%`)

### `adcsbc64`

- Baseline runs: `0.529 0.573 0.543 0.555 0.554`
- Current runs: `0.616 0.618 0.630 0.602 0.622`
- Baseline mean/median: `0.551 / 0.554`
- Current mean/median: `0.618 / 0.618`
- Relative change: `0.891x` (`current` slower by `12.2%`)

### `adc32`

- Baseline runs: `0.548 0.539 0.550 0.547 0.549`
- Current runs: `0.530 0.504 0.504 0.504 0.504`
- Baseline mean/median: `0.547 / 0.548`
- Current mean/median: `0.509 / 0.504`
- Relative change: `1.075x` (`current` faster by `7.0%`)

### `sbc32`

- Baseline runs: `0.543 0.552 0.566 0.544 0.552`
- Current runs: `0.551 0.551 0.553 0.572 0.564`
- Baseline mean/median: `0.551 / 0.552`
- Current mean/median: `0.558 / 0.553`
- Relative change: `0.988x` (`current` slower by `1.3%`)

### `adcsbc32`

- Baseline runs: `0.679 0.676 0.665 0.665 0.687`
- Current runs: `0.687 0.662 0.675 0.682 0.679`
- Baseline mean/median: `0.675 / 0.676`
- Current mean/median: `0.677 / 0.679`
- Relative change: `0.997x` (`current` slower by `0.3%`)

Interpretation:

- These numbers describe the full current experimental tree versus clean
  `v10.2.0`, not the isolated contribution of the plain-`SBC -> sbb` change.
- They confirm that the current branch still carries enough global overhead to
  lose on the 64-bit `ADC/SBC` hot loops, even though `out_asm` now shows a
  direct host `sbb` for plain `SBC`.

## 2026-03-28 Host-Direct Step 15 (plain SBC borrow-chain direct path)

Change:

- Add a minimal AArch64 codegen regression for plain `ADC` / plain `SBC`:
  - `tests/tcg/aarch64/adc-sbc-host-direct.S`
  - `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
  - `run-adc-sbc-host-direct-codegen`
- Keep plain `ADC` on the existing host `adc` chain.
- Switch plain non-setflags `SBC` from the previous `~rm + adc` lowering to a
  true borrow-chain form:
  - `borrow_in = carry_in ^ 1`
  - seed borrow state with `subbo(0, borrow_in)`
  - execute `subbio(lhs, rhs)`

Why:

- The old lowering was functionally correct but still emitted `not + adc`
  instead of a direct host `sbb`.
- Seeding `subbio` via `addco` is not a valid borrow-chain model for the TCG
  optimizer; it triggered `squash_prev_borrowout` because the previous carry
  producer was not a borrow-out producer.
- `subbo(0, borrow_in) + subbio` keeps both the runtime x86 flags and the TCG
  carry/borrow abstraction consistent.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `ninja -C build qemu-system-aarch64` pass
- `run-adc-sbc-host-direct-codegen` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass
- `500/502/531/557` train subset pass

Notes:

- `out_asm` for the new minimal test now shows:
  - plain `ADC` -> `adcq`
  - plain `SBC` -> `sbbq`
- This step intentionally does not touch `ADCS/SBCS` or wider consumer
  expansion.

Perf:

- not measured yet for this step

## 2026-03-28 Debug Update (531 early divergence root cause)

Finding:

- The current `531.deepsjeng_r train` early divergence was traced to an
  always-active semantic bug in `target/arm/tcg/translate-a64.c:do_logic_reg()`,
  not to the raw-flags canonical model.

Root cause:

- For inverted logical register forms (`a->n` true), the current tree first
  inverted `tcg_rm` and then, in the fallback path, unconditionally emitted
  `tcg_gen_and_i64(...)`.
- That broke the non-flags semantics of:
  - `ORN`
  - `EON`
- The bad behavior showed up inside `deepsjeng` bitboard generation and caused
  the first train-output divergence at the old `1121` node count site.

Fix:

- Restore the fallback to call the original logical op callback `fn(...)`.
- Since `tcg_rm` is already inverted when needed, this keeps:
  - `BIC` as `AND`
  - `ORN` as `OR`
  - `EON` as `XOR`

Evidence:

- Before fix:
  - `531.deepsjeng_r train` 60s prefix diverged at line 26 with
    `3 256 0 1121 Bg4 ??`
- After fix:
  - `531.deepsjeng_r train` 60s prefix matches the reference output
  - output file:
    - `~/qemu_nzcv/backendclean-results/spec531/current-after-logicfix-prefix.out`
  - full `train.out` also matches exactly
  - output file:
    - `~/qemu_nzcv/backendclean-results/spec531/current-after-logicfix-full.out`

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4 cmpstress-o3` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass
- `531.deepsjeng_r train` full diff pass
- `500.perlbench_r train` diff pass
- `502.gcc_r train` diff pass
- `557.xz_r train` diff pass

Coverage added:

- `nzcv-status4`:
  - `0x91`: `ORN64 shifted-reg`
  - `0x92`: `EON64 shifted-reg`

Status:

- Full `531 train` rerun is in progress after the semantic fix.

## 2026-03-28 Cleanup Update (debug scaffolding removed)

Cleanup:

- Removed the temporary debug-only scaffolding added during 531 root-cause
  analysis:
  - shadow NZCV state in `CPUARMState`
  - debug helpers in `helper-a64.[ch]`
  - `QEMU_A64_*` diagnostic gates in `translate-a64.c`
  - forced-split / forced-old conditional debug paths

Kept:

- the actual semantic fix in `do_logic_reg()`
- the regression tests for `ORN/EON` shifted-register behavior

Fresh verification after cleanup:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `ninja -C build qemu-system-aarch64` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass
- `500.perlbench_r train` diff pass
- `502.gcc_r train` diff pass
- `531.deepsjeng_r train` diff pass
- `557.xz_r train` diff pass

Result:

- The post-cleanup tree keeps the semantic fix and remains correct on the
  full tracked SPEC train set (`500/502/531/557`).

## 2026-03-28 Debug Update (531 consumer/producer cluster isolation)

Target:

- `531.deepsjeng_r train`
- 60s prefix compare against
  `/home/wangruoyu/cpuspec2017/benchspec/CPU/531.deepsjeng_r/data/train/output/train.out`

Baseline failing prefix:

- current tree starts diverging at line 26
- reference:
  - ` 3     256     0     1162  Bg4 ??`
- current:
  - ` 3     256     0     1121  Bg4 ??`

Experiments:

- `QEMU_A64_FORCE_OLD_CONDSEL=1`
- `QEMU_A64_FORCE_OLD_BCOND=1`
- `QEMU_A64_FORCE_OLD_CONDSEL=1 QEMU_A64_FORCE_OLD_BCOND=1`
- `QEMU_A64_FORCE_OLD_CCMP=1 QEMU_A64_FORCE_OLD_CONDSEL=1 QEMU_A64_FORCE_OLD_BCOND=1`
- `QEMU_A64_FORCE_OLD_PRODUCERS=1`
- `QEMU_A64_FORCE_OLD_PRODUCERS=1 QEMU_A64_FORCE_OLD_CCMP=1 QEMU_A64_FORCE_OLD_CONDSEL=1 QEMU_A64_FORCE_OLD_BCOND=1`

Result:

- all of the above still produce the same line-26 divergence
- the first differing line remains:
  - ` 3     256     0     1121  Bg4 ??`

Interpretation:

- `compare-form consumer`
- `cond-select`
- `generic b.cond`
- `CCMP`
- direct/raw producer subcluster

have all been pushed down in priority for the current `531` bug.

Supporting note:

- disassembly count for `deepsjeng_r_base.mytest-64` shows:
  - `ccmp`: 85
  - `csel`: 189
  - `cset`: 69
  - `csinc`: 3
  - `csneg`: 1
  - `fcsel`: 2
- no hits for:
  - `rmif`
  - `setf8/setf16`
  - `cfinv`
  - `xaflag/axflag`
  - `fccmp`
  - `adc/adcs/sbc/sbcs`

Verification:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

## 2026-03-28 531.deepsjeng_r 隔离结果

Isolation runs were moved under:

- `/home/wangruoyu/qemu_nzcv/backendclean-results/spec531`

60s prefix comparison against SPEC `train.out`:

- `clean5ed`:
  - output: `clean5ed-prefix.out`
  - result: `PREFIX_MATCH 156`
- `backendclean` (`clean front-end + current backend`):
  - output: `backendclean-prefix.out`
  - result: `PREFIX_MATCH 159`
- `backendclean` + current `cpu.h + hflags.c`:
  - output: `backendclean-cpuhflags-prefix.out`
  - result: `PREFIX_MATCH 160`
- `current qemu10.2`:
  - output: `current-prefix.out`
  - result: `FIRST_DIFF 26`
  - ref: ` 3     256     0     1162  Bg4 ??`
  - out: ` 3     256     0     1121  Bg4 ??`
- `backendclean` + current `translate-a64.c` front-end cluster:
  - output: `backendclean-translate-prefix.out`
  - result: `FIRST_DIFF 26`
  - ref: ` 3     256     0     1162  Bg4 ??`
  - out: ` 3     256     0     1121  Bg4 ??`

Conclusion:

- The regression reproduces when current `translate-a64.c` front-end logic is
  overlaid onto the otherwise-correct hybrid build.
- The current backend cluster alone is not sufficient to reproduce the bug.

## 2026-03-28 Correctness Follow-up: 531 all-off still diverges

Setup:

- current `qemu10.2` was run with:
  - `QEMU_A64_DISABLE_HOST_CMPJCC=1`
  - `QEMU_A64_DISABLE_TB_RAW=1`
  - `QEMU_A64_DISABLE_CMP_PENDING_CONSUMERS=1`
  - `QEMU_A64_DISABLE_DIRECT_FLAG_PRODUCERS=1`
  - `QEMU_A64_DISABLE_DIRECT_ADC_SBC=1`
  - `QEMU_A64_FORCE_SPLIT_FLAGS=1`
  - `QEMU_A64_FORCE_OLD_CCMP=1`
- clean reference used:
  - `/home/wangruoyu/qemu_nzcv/clean5ed/build-aarch64-linux-user/qemu-aarch64`

Artifacts:

- current all-off prefix:
  - `/tmp/spec531-alloff.out`
- clean prefix:
  - `/tmp/spec531-clean5ed-prefix.out`

Observed:

- `clean5ed` matches the reference prefix from
  `benchspec/CPU/531.deepsjeng_r/data/train/output/train.out`
- `current all-off` still diverges early, starting around the depth-5 search lines
- `current all-off` prefix is identical to the current default prefix, so the
  all-off diagnostic mode is not introducing a new failure shape

Implication:

- the remaining `531` correctness issue is not explained solely by runtime
  host-direct/raw-flags feature hits
- investigation should prioritize always-active static semantic differences over
  additional runtime flag gating experiments

## 2026-03-27 Correctness Debug Snapshot

Workload:

- `531.deepsjeng_r train`

Observed:

- current `qemu10.2` diverges from reference output very early in the first
  analyzed position
- `/home/wangruoyu/qemu_nzcv/clean5ed` passes the same repro

What was tested:

- fixed the `a64_test_cc_bool_i32()` debug blind spot so bool consumer checks
  really execute on `RAW/SPLIT/pending-compare` paths
- added env-gated runtime partition tests for:
  - `cmp+b.cond` fastpath off
  - `cmp_pending` non-branch consumers off
  - TB raw off
  - direct flag producers off
  - non-setflags `ADC/SBC` direct path off
  - forced split fallback for generic flags writes
  - forced old `CCMP/CCMN` path

Result:

- none of the above changed the early divergence pattern

Interpretation:

- the failing behavior is no longer well explained by the runtime
  producer/consumer optimization path alone
- the next debugging stage should focus on remaining static
  TCG/backend integration differences versus `clean5ed`

## 2026-03-24 Host-Direct Step 16 (`SBCS xzr -> B.cond` via pending compare)

Change:

- Add a compare-like fast path for `SBCS xzr, lhs, rhs` when a future
  `B.cond` is detected in the existing gap window.
- Compute `rhs_eff = rhs + borrow_in` and record the producer as a pending
  `SUB`-style compare instead of materializing raw flags immediately.
- Reuse the existing `cmp + b.cond` direct path from that point onward.
- Add UT `0x8f` (`SBCS xzr -> B.cs`) and `0x90` (`SBCS xzr -> B.mi`).

Why:

- `SBCS xzr, ...` is compare-like: the result is discarded and only NZCV
  matters.
- For this shape, `rhs + borrow_in` converts the instruction into an exact
  compare equivalent, which lets us reuse the already-working `cmp+jcc` path.
- This avoids the more expensive route of:
  - direct `sbb` producer
  - raw flag capture
  - later separate branch consumer

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `ninja -C build qemu-system-aarch64` pass
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Notes:

- `out_asm` for `0x8f` now shows:
  - `rhs_eff` calculation
  - `cmpq`
  - `jae`
- `out_asm` for `0x90` now shows:
  - `rhs_eff` calculation
  - `cmpq`
  - `js`
- Before this step those cases were emitted as:
  - direct `sbb`
  - followed by a separate branch consuming captured raw flags

Perf:

- not measured yet for this step

## 2026-03-24 Host-Direct Step 15 (dedicated `SBCS -> sbb` raw producer)

Change:

- Stop routing `SBCS` through generic `subbo/subbio`.
- Add a dedicated x86 opcode `x86_sbb_capture_rawflags`.
- Use it only for the `SBCS` setflags direct path.
- Keep non-setflags `SBC` on the previous `~rm + adc` chain.
- Add UT `0x8e` (`SBCS32 -> ADC`).

Why:

- The generic borrow-chain optimizer assumes a shape that ARM `SBCS` does not
  satisfy.
- A dedicated x86 op avoids that rewrite entirely and preserves the exact
  host-flags producer we want.
- This also re-enables the highest-value compare-style form:
  `SBCS xzr, ...` as a raw producer.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `ninja -C build qemu-system-aarch64` pass
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4 cmpstress-o3` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Notes:

- `out_asm` for `0x84` now shows:
  - `btl $0, %ebx`
  - `cmc`
  - `sbbq %r14, %r13`
  - `lahf`
  - `seto %al`
- `out_asm` for `0x8e` now shows the 32-bit form:
  - `sbbl %r14d, %r13d`

Perf:

- not measured yet for this step

## 2026-03-20 Host-Direct Step 13 (route ANDS/TST immediate into the fused logical direct subset)

Change:

- Route `ANDS_i/TST_i` into the same fused logical direct path already used by
  the register-form producers.
- Add UT `0x8a` (`TST #imm -> ADC`) and `0x8b` (`ANDS #imm -> ADC`).

Why:

- This extends the logical direct subset without introducing a new state model
  or new raw decode rules.
- It keeps correctness simple by reusing the already-stable fused logical
  producer path.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Notes:

- This step has now been followed by a backend update that adds dedicated
  immediate capture emission for the supported subset.
- Coverage remains partial for 64-bit logical immediates that cannot be
  represented directly in x86 immediate form.

Perf:

- not measured yet for this step

## 2026-03-20 Host-Direct Step 14 (immediate-encoded logical capture; SUBS direct producer)

Change:

- Extend `x86_and_capture_rawflags` / `x86_test_capture_rawflags` so they can
  emit immediate forms directly when the value is representable in x86.
- Route the supported `ANDS_i/TST_i` subset to those immediate-encoded backend
  paths.
- Add direct `SUBS` raw-producer emission via host `sub` + `lahf/seto`.
- Add UT `0x8c` (`SUBS -> ADC`).

Why:

- This removes one more layer of host-constant materialization for the logical
  immediate subset.
- `SUBS` is one of the remaining high-value flag-setting arithmetic producers
  that was still spending cycles on manual NZCV reconstruction.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4` pass
- `run-nzcv-status4` pass
- `run-cmpstress-o3` pass

Notes:

- `out_asm` now shows immediate-encoded `testq $imm` / `andq $imm` for the
  supported logical-immediate subset.
- `out_asm` also shows direct host `subq` + `lahf/seto` for `SUBS`.

Perf:

- not measured yet for this step

## 2026-03-30 Host-Direct Step 22 (extended-register `ADDS/SUBS/CMN/CMP -> ADC/SBC`)

Change:

- Extend `do_addsub_ext()` so it can feed same-TB adjacent plain `ADC/SBC`
  consumers for both:
  - compare-like producers: `CMN/CMP <ext> -> ADC/SBC`
  - materialized producers: `ADDS/SUBS rd,<ext> -> ADC/SBC`
- Keep `SUBS xzr,<ext> -> future B.cond` ahead of adjacent plain `SBC`, so
  the existing compare-to-branch fast path remains first priority.
- Add ext-form host-direct codegen guards:
  - `adc-sbc-host-direct` now checks the ext compare-like/materialized pairs
  - `cmp-bcond-ext-host-direct` now checks the ext branch path with a stricter
    “cmp to jcc without rebuilt decision flags” oracle
- Add ext-form semantic coverage to `nzcv-status4`.
- Add dedicated `_ext` benchmark modes to `adcsbc-bench`.

Why:

- `do_addsub_ext()` was the remaining obvious hole after register-form and
  immediate-form arithmetic direct producers.
- The ext rhs is already a live post-extension temp, so this path can reuse
  the existing `pending_cc` skeleton without the immediate-form constant glue.

Correctness:

- `ninja -C build-aarch64-linux-user qemu-aarch64` pass
- `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ... adc-sbc-host-direct` pass
- `tests/tcg/aarch64/check-cmp-bcond-ext-host-direct.sh ... cmp-bcond-ext-host-direct` pass
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu .../nzcv-status4` pass
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu .../cmpstress-o3` pass
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench` pass

Notes:

- The current good ext `B.cond` host shape is:
  - host `cmp`
  - raw-flags capture (`push/lahf/seto/pop`)
  - direct `jcc`
  The branch oracle now explicitly allows raw capture, while still rejecting
  `test`, a second `cmp`, and carry/borrow decode/rebuild shapes.
- `nzcv-status4` now covers:
  - `CMN64/32 ext -> ADC`
  - `ADDS64/32 ext rd -> ADC`
  - `CMP64/32 ext -> SBC`
  - `SUBS64/32 ext rd -> SBC`
  - `SUBS xzr,<ext> -> shared B.eq consumer`
- `_ext` benchmark helpers were checked in both source and objdump and really
  lower to `uxtx/uxtw` extended-register forms.

Perf:

- same tree
- same binary
- `build-aarch64-linux-user/qemu-aarch64 -cpu max`
- `200000000` iterations for the main A/B set
- add-side only toggles `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`
- compare-like sub-side only toggles `QEMU_A64_DISABLE_CMP_SBC_DIRECT=1`
- materialized sub-side only toggles `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1`

`200000000` iterations, median:

- `cmnadc64_ext`
  - on: `0.34 0.33 0.32`
  - off: `0.42 0.41 0.41`
  - median: `0.33` vs `0.41`
  - direct faster by about `19.5%`
- `cmnadc32_ext`
  - on: `0.41 0.42 0.42`
  - off: `0.53 0.54 0.53`
  - median: `0.42` vs `0.53`
  - direct faster by about `20.8%`
- `addsadc64_ext`
  - on: `0.33 0.32 0.34`
  - off: `0.44 0.41 0.41`
  - median: `0.33` vs `0.41`
  - direct faster by about `19.5%`
- `addsadc32_ext`
  - on: `0.49 0.50 0.48`
  - off: `0.49 0.49 0.50`
  - median: `0.49` vs `0.49`
  - essentially flat
- `cmpsbc64_ext`
  - on: `0.38 0.37 0.37`
  - off: `0.49 0.49 0.49`
  - median: `0.37` vs `0.49`
  - direct faster by about `24.5%`
- `cmpsbc32_ext`
  - on: `0.42 0.40 0.45`
  - off: `0.54 0.53 0.54`
  - median: `0.42` vs `0.54`
  - direct faster by about `22.2%`
- `subsbc64_ext`
  - on: `0.33 0.35 0.34`
  - off: `0.45 0.44 0.46`
  - median: `0.34` vs `0.45`
  - direct faster by about `24.4%`
- `subsbc32_ext`
  - on: `0.49 0.50 0.49`
  - off: `0.55 0.52 0.53`
  - median: `0.49` vs `0.53`
  - direct faster by about `7.5%`

`400000000` iterations spot-check:

- `cmnadc32_ext`
  - on: `0.83 0.81 0.80`
  - off: `1.04 1.05 1.05`
- `cmpsbc32_ext`
  - on: `0.81 0.82`
  - off: `1.08 1.05`

One early `cmnadc32_ext off` run reported `0.54`; it did not reproduce on the
dedicated rerun, so it was treated as a timing outlier rather than a real
signal.

Current reading:

- ext-form focused correctness is green
- ext-form `_ext` benchmark modes are now real and stable
- the perf hard gate did not find any stable negative path
- `addsadc32_ext` is basically neutral, but it is not a regression source
