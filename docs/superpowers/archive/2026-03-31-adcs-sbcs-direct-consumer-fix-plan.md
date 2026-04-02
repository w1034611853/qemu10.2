> Archive: historical plan kept for reference. The work it described has been
> closed out and is now tracked from `progress.md`.

# ADCS/SBCS Direct Consumer 修复计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复最新 `ADCS/SBCS` direct-consumer merge 中已确认的语义与测试缺口，确保当前实现只保留“正确且被测试覆盖”的路径。

**Architecture:** 本次修复不继续扩功能面，而是先把实现收回到语义自洽的最小集合。具体做法是：补上 `ADCS/SBCS` setflags direct helper 缺失的 raw-flags capture；把当前并不成立的 compare-like `CMN/CMP -> ADCS/SBCS` 路径从 producer lookahead 中收窄掉，只保留 materialized `ADDS/SUBS -> ADCS/SBCS`；最后补真正命中 adjacency 的测试，并把 summary 文档改成与代码一致。

**Tech Stack:** QEMU TCG、AArch64 translator、x86 host backend、AArch64 汇编回归测试、shell codegen guard

---

## File Map

| 文件 | 责任 |
|------|------|
| `target/arm/tcg/translate-a64.c` | 修正 setflags helper 的 raw-flags 生命周期；收窄 producer lookahead 作用范围；保持 `SBCS xzr -> B.cond` 优先级 |
| `tests/tcg/aarch64/adc-sbc-host-direct.S` | 把 ADCS/SBCS 测试块改成真正命中 adjacency；补齐 materialized `reg/imm/ext`；为 compare-like 收窄提供“非直通”观测块 |
| `tests/tcg/aarch64/check-adc-sbc-host-direct.sh` | 更新 codegen oracle：对 materialized `reg/imm/ext` 做 direct 硬检查；对 compare-like `CMN/CMP -> ADCS/SBCS` 做“必须走 decode/非直通”的负向断言 |
| `tests/tcg/aarch64/nzcv-status4.S` | 增加“ADCS/SBCS 后立刻读 flags”的语义回归，验证最终 flags 来自 consumer |
| `docs/superpowers/summaries/2026-03-31-adcs-sbcs-direct-consumer-summary.md` | 修正文档中过度声明的覆盖范围与 helper 行为描述 |
| `docs/superpowers/summaries/2026-03-31-adcs-sbcs-test-summary.md` | 修正测试说明，明确哪些路径真的命中 direct、哪些目前未覆盖 |

## 范围与决策

### 本计划明确修什么

- 修复 `a64_try_emit_x86_add_adcs()` / `a64_try_emit_x86_cmp_sbcs()` 没有把 consumer 新 raw flags 写回 `cpu_x86_raw_flags` 的问题
- 收窄当前不自洽的 compare-like `CMN/CMP -> ADCS/SBCS` 相邻路径
- 补上真正覆盖 adjacency 和 “consumer 后立刻读 flags” 的测试
- 修正文档与代码不一致的结论

### 本计划明确不做什么

- 不在这一步重新打开 compare-like `CMN/CMP -> ADCS/SBCS` 功能
- 不做新的 perf benchmark 设计或 timing A/B
- 不扩新的 env gate
- 不改 plain `ADC/SBC` 已经稳定的 direct-consumer 逻辑

### 为什么先收窄而不是继续补 compare-like

当前 merge 的两个高优先级问题里，真正危险的是：

- setflags helper 自己的 flags 生命周期不完整
- compare-like producer 已经被 lookahead 命中，但 consumer helper 又拒绝它

这意味着当前 compare-like `CMN/CMP -> ADCS/SBCS` 不是“性能未优化”，而是“控制流本身不自洽”。最小、安全、可快速验证的修法是先把这条路径从支持面里拿掉，只保留已经具备 live `CF` 的 materialized producer：

- `ADDS rd -> ADCS`
- `SUBS rd -> SBCS`

等这条收口完成后，再单独为 compare-like `CMN/CMP -> ADCS/SBCS` 做下一份设计和实现计划。

---

## Task 1: 先补红灯测试，锁定当前 merge 的三个问题

**Files:**
- Modify: `tests/tcg/aarch64/adc-sbc-host-direct.S`
- Modify: `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
- Modify: `tests/tcg/aarch64/nzcv-status4.S`

- [ ] **Step 1: 为 materialized `ADDS/SUBS -> ADCS/SBCS` 写真正相邻的 `reg/imm/ext` 测试块**

把当前 ADCS/SBCS 测试块里 producer 与 consumer 中间的 `mov` 搬到 producer 之前，保证真正的 guest 序列形如：

```asm
    mov     x6, #9
    mov     x7, #3
    adds    x5, x0, x1
    adcs    x8, x6, x7
```

和：

```asm
    mov     x6, #9
    mov     x7, #3
    subs    x5, x0, x1
    sbcs    x8, x6, x7
```

这一步至少补齐 6 组真正相邻的 materialized block：

- `ADDS reg -> ADCS`
- `SUBS reg -> SBCS`
- `ADDS imm -> ADCS`
- `SUBS imm -> SBCS`
- `ADDS ext -> ADCS`
- `SUBS ext -> SBCS`

不要在这一步继续保留“看起来在测 `CMN/CMP -> ADCS/SBCS`，实际上并不相邻”的块。

- [ ] **Step 2: 给 `nzcv-status4.S` 增加“ADCS/SBCS 后立即读 flags”用例，并把预期值钉死**

增加至少 4 个 case：

- `ADDS64 -> ADCS64 -> MRS NZCV`
- `SUBS64 -> SBCS64 -> MRS NZCV`
- `ADDS32 -> ADCS32 -> MRS NZCV`
- `SUBS32 -> SBCS32 -> MRS NZCV`

每个 case 都要满足：

- producer 和 `ADCS/SBCS` 真正相邻
- `MRS NZCV` 紧跟 consumer 或通过现有 shared consumer 立即读取
- producer 与 consumer 的 `NZCV` 至少有 1 位不同
- 在测试里直接写出 consumer 预期 `NZCV`，不要只写“来自 consumer”

推荐直接用这组值，避免同态 case 掩盖 bug：

- `ADDS64 -> ADCS64`
  - producer：`movn x0,#0 ; mov x1,#1 ; adds x5, x0, x1`
  - producer `NZCV = 0x6`
  - consumer：`mov x6,#9 ; mov x7,#3 ; adcs x8, x6, x7`
  - consumer `NZCV = 0x0`
- `SUBS64 -> SBCS64`
  - producer：`mov x0,#0 ; mov x1,#1 ; subs x5, x0, x1`
  - producer `NZCV = 0x8`
  - consumer：`mov x6,#9 ; mov x7,#3 ; sbcs x8, x6, x7`
  - consumer `NZCV = 0x2`

32-bit case 也沿用同样思路，确保 producer / consumer 的 `NZCV` 不是同态。

- [ ] **Step 3: 把 codegen guard 分成“支持路径硬检查”和“收窄路径负向检查”两类**

`check-adc-sbc-host-direct.sh` 对 materialized 路径做 direct 硬检查：

- `ADDS reg -> ADCS`
- `SUBS reg -> SBCS`
- `ADDS imm -> ADCS`
- `SUBS imm -> SBCS`
- `ADDS ext -> ADCS`
- `SUBS ext -> SBCS`

检查点：

- `ADDS -> ADCS`：`addq/addl` 后接 `adcq/adcl`
- `SUBS -> SBCS`：`subq/subl` 后接 `sbbq/sbbl`
- 中间不允许出现 canonical carry decode 胶水：
  - `shr`
  - `and`
  - `xor`
  - `not`
  - 一般 `setcc`

对 compare-like `CMN/CMP -> ADCS/SBCS`，新增真正相邻的 block，但这一步不把它们当 direct 支持路径；相反，要做“收窄成功”的负向断言：

- `CMN/CMP` 后面紧跟 `ADCS/SBCS`
- host block 里必须能看到 carry/borrow decode 胶水
  - add-side：至少有 `shrl` + `andl`
  - sub-side：至少有 `shrl` + `andl`，并允许现有 `xorl $1`
- 不能出现 materialized direct 的紧凑 `add/sub + adc/sbb` 形状被误判成已支持

这组负向 oracle 的目的不是证明 fallback“最优”，而是直接证明 finding #2 已被收窄出 direct 覆盖面。

- [ ] **Step 4: 运行测试，确认当前代码先暴露缺口**

Run:

```bash
ninja -C build-aarch64-linux-user qemu-aarch64
make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user adc-sbc-host-direct nzcv-status4
tests/tcg/aarch64/check-adc-sbc-host-direct.sh build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
```

Expected:

- 在修实现之前，至少有一项新的 flags 语义测试或 codegen 检查失败
- 失败点应直接对应当前 review finding，而不是随机 unrelated 回归

- [ ] **Step 5: 提交红灯测试**

```bash
git add tests/tcg/aarch64/adc-sbc-host-direct.S tests/tcg/aarch64/check-adc-sbc-host-direct.sh tests/tcg/aarch64/nzcv-status4.S
git commit -m "tests/aarch64: expose ADCS/SBCS direct-consumer gaps"
```

---

## Task 2: 修 setflags helper 的 raw-flags capture

**Files:**
- Modify: `target/arm/tcg/translate-a64.c`

- [ ] **Step 1: 对照现有正确先例，明确 helper 应该补什么**

阅读：

- `gen_adc_CC()` 的 direct 分支
- `a64_try_emit_x86_add_adcs()`
- `a64_try_emit_x86_cmp_sbcs()`

重点对照：

- 现有正确路径会在 host `adc/sbb` 后把 raw flags 写到 `cpu_x86_raw_flags`
- 新 helper 当前只 `a64_set_raw_flags_state()`，没有 capture 新 raw flags

- [ ] **Step 2: 给 `a64_try_emit_x86_add_adcs()` 补 consumer raw-flags capture**

64-bit 和 32-bit 都要补。

目标形状：

```c
    a64_emit_addci_*(...)
    a64_emit_x86_capture_rawflags(raw)
    tcg_gen_mov_i32(cpu_x86_raw_flags, raw)
    a64_set_raw_flags_state(s, A64_X86_CC_ADCxx)
```

注意：

- capture 的是 consumer `ADCS` 之后的 flags
- 不能恢复 producer raw state
- `valid = false` 仍然保留

- [ ] **Step 3: 给 `a64_try_emit_x86_cmp_sbcs()` 补 consumer raw-flags capture**

目标形状与 add-side 对称：

```c
    a64_emit_subbi_*(...)
    a64_emit_x86_capture_rawflags(raw)
    tcg_gen_mov_i32(cpu_x86_raw_flags, raw)
    a64_set_raw_flags_state(s, A64_X86_CC_SBCxx)
```

注意 borrow 语义不要改，只补 raw capture。

- [ ] **Step 4: 运行 focused correctness**

Run:

```bash
ninja -C build-aarch64-linux-user qemu-aarch64
tests/tcg/aarch64/check-adc-sbc-host-direct.sh build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
```

Expected:

- 新增的 “consumer 后立即读 flags” 用例通过
- 已有 plain `ADC/SBC` guard 不回退

- [ ] **Step 5: 提交 helper 修复**

```bash
git add target/arm/tcg/translate-a64.c
git commit -m "target/arm/tcg: capture raw flags in ADCS/SBCS direct helpers"
```

---

## Task 3: 收窄 compare-like `CMN/CMP -> ADCS/SBCS` 覆盖，恢复控制流自洽

**Files:**
- Modify: `target/arm/tcg/translate-a64.c`

- [ ] **Step 1: 把 producer lookahead 从“共享 plain/setflags”拆成 compare-like 与 materialized 两档**

当前的 `a64_find_adjacent_plain_adc()` / `a64_find_adjacent_plain_sbc_*()` 已经被扩成会识别 `ADCS/SBCS`，但 compare-like producer 实际上并不能消费这条信息。

这一步的目标是把支持面收回到：

- compare-like producer：
  - 仍只认 plain `ADC/SBC`
- materialized producer：
  - 可以认 `ADC/SBC`
  - 也可以认 `ADCS/SBCS`

实现方式二选一：

- 新增 materialized 专用 lookahead helper
- 或给现有 helper 加显式参数，区分是否允许 setflags consumer

不要继续沿用当前“一个 helper 同时喂 compare-like 和 materialized”的写法。

- [ ] **Step 2: 在 `do_addsub_reg()` / `do_addsub_imm()` / `do_addsub_ext()` 中按 producer 类型接不同 lookahead**

目标行为：

- `CMN/CMP` 不再因为相邻 `ADCS/SBCS` 跳过旧 lowering
- `ADDS/SUBS rd` 仍可因为相邻 `ADCS/SBCS` 建立 `pending_cc`

注意 immediate 现有收窄边界不能被顺手放大：

- `CMN32 / ADDS xzr,#imm -> ADC32` 既有收窄仍然保留

同时要确认 materialized `imm/ext` 仍然保留 setflags consumer 命中：

- `ADDS imm/ext -> ADCS`
- `SUBS imm/ext -> SBCS`

- [ ] **Step 3: 保持 `SBCS xzr -> future B.cond` 优先级不变**

`do_adc_sbc()` 当前对：

- `setflags && is_sub && rd == 31`

会优先走 `lazy_bcond_cmp`。本步不能破坏这条路径。

需要重新确认：

- `SBCS xzr -> future B.cond` 仍先于新的 setflags direct consumer
- `SBCS xzr` 不被误当作 materialized `SUBS rd -> SBCS`

- [ ] **Step 4: 用 codegen / trace 双信号证明 compare-like 收窄已生效**

在已有 codegen 负向 oracle 之外，再加一个轻量 trace 检查：

Run:

```bash
build-aarch64-linux-user/qemu-aarch64 -d op,nochain -D /tmp/adcs-sbcs-fix-trace.log build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
```

然后检查：

- materialized block 仍能看到
  - `via=ADCS-x86-add-adcs`
  - `via=SBCS-x86-cmp-sbcs`
- compare-like 真正相邻 block 不再出现这两个 consumer tag

如果 trace 很难按块定位，至少要把脚本/注释写清楚：这一步需要一个“compare-like 不再被 setflags direct helper 消费”的正面信号，不能只靠没有报错。

- [ ] **Step 5: 运行 focused correctness**

Run:

```bash
ninja -C build-aarch64-linux-user qemu-aarch64
tests/tcg/aarch64/check-adc-sbc-host-direct.sh build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
build-aarch64-linux-user/qemu-aarch64 -d op,nochain -D /tmp/adcs-sbcs-fix-trace.log build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3
```

Expected:

- materialized `reg/imm/ext ADDS/SUBS -> ADCS/SBCS` 保持可命中 direct path
- compare-like `CMN/CMP -> ADCS/SBCS` 已有明确的“非直通 / 不再被 setflags direct helper 消费”证据
- `cmpstress-o3` 继续输出既有 hash

- [ ] **Step 6: 提交收窄修复**

```bash
git add target/arm/tcg/translate-a64.c
git commit -m "target/arm/tcg: narrow ADCS/SBCS direct consumers to materialized producers"
```

---

## Task 4: 让测试文档与实际代码/覆盖范围重新对齐

**Files:**
- Modify: `docs/superpowers/summaries/2026-03-31-adcs-sbcs-direct-consumer-summary.md`
- Modify: `docs/superpowers/summaries/2026-03-31-adcs-sbcs-test-summary.md`

- [ ] **Step 1: 修正 implementation summary 的覆盖声明**

必须改掉这些过度声明：

- 不再写“`CMN/CMP/ADDS/SUBS` 都是 ADCS/SBCS 的直接消费者”
- 不再把 `REWINDABLE_CMP -> fallback` 写成“已验证的支持行为”
- 不再声称当前新增 `0xab-0xae` 是在测 “pending producer -> ADCS/SBCS consumer”

要明确改成：

- 当前 merge 修复后承诺支持的是 materialized
  `ADDS/SUBS rd -> ADCS/SBCS`
- compare-like `CMN/CMP -> ADCS/SBCS` 已收窄出本次支持面

- [ ] **Step 2: 修正 test summary 的测试描述**

必须明确：

- 之前那些 `CMN/CMP -> ADCS/SBCS` block 中间有 `mov`，并不相邻
- 修复后新的 codegen guard 只对 materialized direct path 做硬检查
- `nzcv-status4` 新增项里，哪些是在测 consumer flags，哪些是在测 setflags producer 链
- compare-like `CMN/CMP -> ADCS/SBCS` 当前不是“已支持 fallback”，而是“已明确收窄出支持面”

- [ ] **Step 3: 写入本次修复后的实际验证命令与结果**

文档里只写本次实际跑过的 focused correctness：

- `ninja -C build-aarch64-linux-user qemu-aarch64`
- `check-adc-sbc-host-direct.sh`
- `nzcv-status4`
- `cmpstress-o3`

不要写 timing A/B，不要写 CPU SPEC perf。

- [ ] **Step 4: 提交文档修订**

```bash
git add docs/superpowers/summaries/2026-03-31-adcs-sbcs-direct-consumer-summary.md docs/superpowers/summaries/2026-03-31-adcs-sbcs-test-summary.md
git commit -m "docs: align ADCS/SBCS summaries with repaired scope"
```

---

## Task 5: 最终回归与交接

**Files:**
- Modify: `codex_a64_x86_status4_handoff.md`（如需记录）
- Optional: `a64_tcg_cmpjcc_perf_results.md`（仅记录“本轮未做 perf”这一事实时再改）

- [ ] **Step 1: 运行完整 focused correctness 套件**

Run:

```bash
ninja -C build-aarch64-linux-user qemu-aarch64
tests/tcg/aarch64/check-adc-sbc-host-direct.sh build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
build-aarch64-linux-user/qemu-aarch64 -d op,nochain -D /tmp/adcs-sbcs-fix-trace.log build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct
build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4
build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3
```

Expected:

- 全部通过
- `nzcv-status4` 输出 `PASS`
- `cmpstress-o3` 输出既有稳定 hash
- trace / oracle 能区分：
  - materialized `reg/imm/ext` 仍命中 setflags direct helper
  - compare-like `CMN/CMP -> ADCS/SBCS` 不再命中 setflags direct helper

- [ ] **Step 2: 记录“本轮不做 perf”的边界**

如果需要在 handoff 里补一句，明确：

- 本轮只修 correctness / codegen / test coverage
- 完整性能测试由用户后续执行

- [ ] **Step 3: 做最终提交或生成 handoff**

如果所有任务都按分提交完成，这一步只需要整理交接摘要；如果前面没有细分提交，则在这里补一次总提交。

建议 handoff 至少包含：

- 当前承诺支持的路径：materialized `ADDS/SUBS -> ADCS/SBCS`
- 明确未支持的路径：compare-like `CMN/CMP -> ADCS/SBCS`
- 已跑 focused correctness
- 待用户执行 perf

---

## 完成标准

- `a64_try_emit_x86_add_adcs()` / `a64_try_emit_x86_cmp_sbcs()` 会把 consumer 新 raw flags 写入 `cpu_x86_raw_flags`
- `ADCS/SBCS` 后立刻读 `NZCV` / 条件码时，读到的是 consumer flags
- compare-like `CMN/CMP -> ADCS/SBCS` 不再处于“producer lookahead 命中但 consumer helper 拒绝”的不自洽状态
- host codegen guard 真正命中并验证 materialized `reg/imm/ext ADDS/SUBS -> ADCS/SBCS`
- compare-like 收窄有明确的 codegen / trace 证据，而不是只靠“没有报错”
- 两份 summary 文档与代码和测试覆盖范围一致
- 不做 perf 测试，只为用户后续 perf 提供一个语义与测试都可靠的基线
