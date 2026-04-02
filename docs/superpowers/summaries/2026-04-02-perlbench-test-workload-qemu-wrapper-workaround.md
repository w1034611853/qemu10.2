# 500.perlbench_r Test-Workload QEMU Wrapper Workaround

## Goal

Provide a repeatable way to validate whether a `500.perlbench_r` `test`
workload miscompare is caused by the NZCV optimization itself, or by nested
Perl subprocesses escaping the outer `qemu-aarch64` launcher.

## Problem Summary

The top-level SPEC command runs:

```sh
qemu-aarch64 ... perlbench_r_base.mytest-64 -I. -I./lib test.pl
```

That only wraps the *outer* Perl process.

Inside the Perl test harness, `t/TEST` launches more Perl subprocesses. In the
SPEC CPU copy used here, the relevant path is built in `t/TEST` and many test
files use `#!./perl`.

If those nested subprocesses execute the AArch64 `perlbench_r_base.mytest-64`
binary directly on the x86 host, the host shell treats the ELF file like a
script and emits errors such as:

```text
perlbench_r_base.mytest-64: 1: Syntax error: word unexpected (expecting ")")
```

That failure mode produces a large `test.out` miscompare, but it is *not* by
itself evidence that the NZCV optimization is functionally wrong.

## When To Use This

Use this workaround when:

- `500.perlbench_r` `test` workload reports a miscompare
- `makerand.out` still compares cleanly
- `test.err` contains repeated shell syntax errors for
  `perlbench_r_base.mytest-64`

Do **not** use this as the main correctness gate for the optimization branch.
It is a diagnostic workaround for the `test` workload.

## Preconditions

Assumptions used below:

- SPEC root: `/home/wangruoyu/cpuspec2017`
- QEMU binary: `/home/wangruoyu/qemu10.2/build-aarch64-linux-user/qemu-aarch64`
- The failing run directory already exists:
  `benchspec/CPU/500.perlbench_r/run/run_base_test_mytest-64.0000`

## Repeatable Procedure

### 1. Define paths

```sh
SPEC=/home/wangruoyu/cpuspec2017
QEMU=/home/wangruoyu/qemu10.2/build-aarch64-linux-user/qemu-aarch64
RUN_DIR="$SPEC/benchspec/CPU/500.perlbench_r/run/run_base_test_mytest-64.0000"
SCRATCH=/tmp/perlbench_test_wrap
```

### 2. Copy the SPEC run directory to scratch space

Keep the original SPEC run tree untouched.

```sh
rm -rf "$SCRATCH"
cp -a "$RUN_DIR" "$SCRATCH"
```

### 3. Rename the real AArch64 Perl binary

```sh
mv "$SCRATCH/perlbench_r_base.mytest-64" \
   "$SCRATCH/perlbench_r_base.mytest-64.real"
```

### 4. Install a same-name wrapper that always re-enters QEMU

Create `"$SCRATCH/perlbench_r_base.mytest-64"` with:

```sh
cat > "$SCRATCH/perlbench_r_base.mytest-64" <<'EOF'
#!/bin/sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
QEMU_BIN="/home/wangruoyu/qemu10.2/build-aarch64-linux-user/qemu-aarch64"
GUEST_BIN="$SELF_DIR/perlbench_r_base.mytest-64.real"

exec "$QEMU_BIN" -L /usr/aarch64-linux-gnu "$GUEST_BIN" "$@"
EOF
chmod +x "$SCRATCH/perlbench_r_base.mytest-64"
```

### 5. Force the nested Perl launcher in `t/TEST` to use the wrapper

Patch the `type eq 'perl'` path in `t/TEST` so nested subprocesses use the
scratch wrapper explicitly:

```sh
perl -0pi -e \
  "s|my \\$perl = '\\.\\./'\\.\\$\\^X; # SPEC CPU; was \\$options->\\{perl\\};|my \\$perl = '$SCRATCH/perlbench_r_base.mytest-64'; # force nested perl through qemu wrapper|" \
  "$SCRATCH/t/TEST"
```

This is the important step. Renaming the outer binary alone is not sufficient,
because the harness can still derive a direct path to the real guest binary via
`$^X`.

### 6. Re-run the two `test` workload commands

```sh
cd "$SCRATCH"

"$SCRATCH/perlbench_r_base.mytest-64" -I. -I./lib makerand.pl \
  > makerand.wrap.out 2> makerand.wrap.err

"$SCRATCH/perlbench_r_base.mytest-64" -I. -I./lib test.pl \
  > test.wrap.out 2> test.wrap.err
```

### 7. Compare against the official SPEC outputs

```sh
"$SPEC/bin/specperl" "$SPEC/bin/harness/specdiff" \
  -m -l 10 --floatcompare --nonansupport \
  "$SPEC/benchspec/CPU/500.perlbench_r/data/test/output/makerand.out" \
  "$SCRATCH/makerand.wrap.out" > "$SCRATCH/makerand.wrap.cmp"

"$SPEC/bin/specperl" "$SPEC/bin/harness/specdiff" \
  -m -l 10 --floatcompare --nonansupport \
  "$SPEC/benchspec/CPU/500.perlbench_r/data/test/output/test.out" \
  "$SCRATCH/test.wrap.out" > "$SCRATCH/test.wrap.cmp"
```

## Expected Success Criteria

After the workaround is applied correctly:

- `makerand.wrap.err` is empty
- `test.wrap.err` is empty
- `specdiff` returns `0` for both `makerand.wrap.out` and `test.wrap.out`

In the validation run used to derive this workaround:

- `test.wrap.err` became empty
- `test.wrap.out` returned to normal `ok` lines
- `specdiff` on `test.wrap.out` returned `0`

## Interpretation

If the wrapped scratch run passes the above checks, then the original
`500.perlbench_r` `test` miscompare is very likely caused by the nested Perl
subprocesses bypassing QEMU, not by the NZCV optimization corrupting guest
results.

That means:

- the original failing `test` run is **not** a clean proof of an optimization
  correctness bug
- further NZCV correctness triage should prefer workloads that do not depend on
  nested guest interpreter self-launching, or should use an equivalent wrapper
  strategy

## Limitations

- This is a diagnostic workaround, not a production SPEC config integration.
- It validates a copied scratch run directory, not the original `runcpu` run
  tree in place.
- It is specific to `500.perlbench_r` `test` workload behavior.
- If you want the same behavior directly under `runcpu`, you will need a more
  systematic wrapper strategy for nested guest self-exec paths.

## Cleanup

```sh
rm -rf "$SCRATCH"
```
