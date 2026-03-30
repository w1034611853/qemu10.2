# extended-form `ADDS/SUBS/CMN/CMP -> ADC/SBC` 直通设计

**日期：** 2026-03-30

**状态：** 草案已确认，可进入实现计划

## 目标

在 register-form 和 immediate-form 都已经接入相邻 `ADC/SBC` direct-consumer
骨架之后，把 `do_addsub_ext()` 这档也补齐：

- `CMN / ADDS xzr, rn, rm, <ext> -> plain ADC`
- `CMP / SUBS xzr, rn, rm, <ext> -> plain SBC`
- `ADDS rd, rn, rm, <ext> -> plain ADC`
- `SUBS rd, rn, rm, <ext> -> plain SBC`

目标仍然保持一致：

- producer 在 x86 host 上把 live `CF` 留在当前 lowering 链上
- consumer 直接发 plain host `adc/sbb`
- 命中后继续把 raw-flags 恢复到 canonical state

这一步优先复用已经稳定的：

- `pending_cc.kind`
- `pending_cc.cc_op`
- `a64_try_emit_x86_add_adc()`
- `a64_try_emit_x86_cmp_sbc()`
- 现有 env gate 与 focused correctness / perf 口径

## 为什么现在做这一步

当前 arithmetic 相邻直通的覆盖已经是：

- register-form：
  - `CMN/CMP -> ADC/SBC`
  - `ADDS/SUBS rd -> ADC/SBC`
- immediate-form：
  - 保留大部分 direct path
  - 只刻意排除 `CMN32 / ADDS xzr,#imm -> ADC32`

而 `do_addsub_ext()` 还明显停在更早的状态：

- 只保留 `SUBS xzr, ..., <ext> -> B.cond` 这条 compare-to-branch 预判
- 没有相邻 plain `ADC/SBC` 的 producer 预判
- 没有 materialized producer 的 pending-cc 记录

所以当前空白位已经集中到 extended-register 这档。

## 当前实现约束

这一步和 immediate-form 最大的不同是：ext rhs 在 translator 里本来就会先变成一个
live `TCGv_i64`。

`do_addsub_ext()` 的现有形状是：

- 先 `read_cpu_reg()` 取 `rm`
- 再 `ext_and_shift_reg(tcg_rm, tcg_rm, a->st, a->sa)`
- 之后才把扩展后的 `tcg_rm` 喂给 `gen_add_CC()` / `gen_sub_CC()`

这意味着：

- compare-like producer 不存在 immediate-form 那种 “constant 不能直接喂 fused op”
  的问题
- consumer 侧看到的 `rhs` 仍然是普通 live temp
- 在数据形状上，这一步比 immediate-form 更接近 register-form

因此这一步不需要再引入 immediate 那样的局部 temp 物化策略，也不需要先验地把
`CMN32` compare-like 路径排除在外。

## 非目标

这一步不做：

- `do_addsub_imm()` 的进一步扩容
- gap / cross-TB 扩展
- 新 env gate
- 新 backend opcode 系列
- 一次性把 ext / reg / imm 三套 producer 再重构成单一 helper
- 其它 arithmetic/logical producer 的泛化

## 候选方案与取舍

### 方案 1：只做 materialized extended producer

范围只收：

- `ADDS rd, ..., <ext> -> ADC`
- `SUBS rd, ..., <ext> -> SBC`

优点：

- 改动最窄
- 不会碰 compare-like `CMN/CMP` producer

缺点：

- 会留下 `CMN/CMP <ext>` 这块明显空白
- 很快还得再回来补 compare-like 版本

这一步不选它作为最终方案。

### 方案 2：完整 extended-form producer 扩展，沿用现有 pending-cc 骨架

范围同时覆盖：

- compare-like producer
- materialized producer

producer 侧只需要补：

- 相邻 plain `ADC/SBC` 预判
- `pending_cc.kind` 记录
- `cc_op` 选择

consumer / backend 逻辑尽量不改。

优点：

- 和 register-form 的实现最接近
- rhs 已经是 live temp，不会再踩 immediate-form 那种 constant 约束
- 这一步的性能风险主要来自 code-shape 变化，而不是额外胶水

缺点：

- 需要小心不误伤现有 `B.cond` compare-like 路径
- benchmark 必须确认真的在测 `<ext>` producer，而不是退化成 register-form

这一步采用此方案。

### 方案 3：先抽统一 helper，再把 ext-form 接进去

也就是先把 `do_addsub_reg()` / `do_addsub_imm()` / `do_addsub_ext()` 的
producer 预判和 pending-cc record 再抽一层通用 helper，再扩 feature。

优点：

- 结构上最整齐
- 从长期演进角度更统一

缺点：

- 这一步的目标是“补 ext-form 空白位”，不是“再做一轮框架收整”
- 会把 feature 扩展和结构重整绑在一起，review 与风险都变大

这一步不采用。

## 选定方案

### 总体思路

让 `do_addsub_ext()` 在结构上向 `do_addsub_reg()` 对齐：

- producer 侧增加相邻 plain `ADC/SBC` 预判
- compare-like producer 命中 direct path 时跳过旧的 flags lowering
- materialized producer 继续走现有 `gen_add_CC()` / `gen_sub_CC()`
- 命中后通过现有 `pending_cc.kind + cc_op + lhs/rhs` 接入 consumer

换句话说，这一步是“把 ext-form producer 接上现有骨架”，不是另起一条新链路。

## producer 设计

### 1. compare-like extended producer

覆盖：

- `SUBS xzr, rn, rm, <ext>` / `CMP rn, rm, <ext>`
- `ADDS xzr, rn, rm, <ext>` / `CMN rn, rm, <ext>`

命中条件：

- same TB
- next guest insn 与当前 producer 真正相邻
- next insn 是 plain `SBC` 或 plain `ADC`
- 仍受现有 env gate 控制：
  - `CMP/SUBS(xzr) -> SBC` 走 `QEMU_A64_DISABLE_CMP_SBC_DIRECT`
  - `CMN/ADDS(xzr) -> ADC` 走 `QEMU_A64_DISABLE_ADD_ADC_DIRECT`

lowering 方案：

- 命中后不发旧的 `gen_add_CC()` / `gen_sub_CC()`
- 记录：
  - `pending_cc.kind = A64_PENDING_CC_REWINDABLE_CMP`
  - `pending_cc.lhs = tcg_rn`
  - `pending_cc.rhs = tcg_rm`
  - `pending_cc.cc_op = ADDxx / SUBxx`

注意点：

- `tcg_rm` 必须是已经完成 `ext_and_shift_reg()` 之后的 live 值
- 也就是说 direct path 观察到的是“扩展后的 rhs”，不是原始 guest `rm`

### 2. materialized extended producer

覆盖：

- `ADDS rd, rn, rm, <ext> -> plain ADC`
- `SUBS rd, rn, rm, <ext> -> plain SBC`

命中条件：

- same TB
- next guest insn 真正相邻
- next insn 是 plain `ADC` 或 plain `SBC`
- 仍受现有 env gate 控制：
  - add-side 走 `QEMU_A64_DISABLE_ADD_ADC_DIRECT`
  - sub-side 走 `QEMU_A64_DISABLE_SUB_SBC_DIRECT`

lowering 方案：

- producer 继续走现有 `gen_add_CC()` / `gen_sub_CC()`
- 命中后记录：
  - `pending_cc.kind = A64_PENDING_CC_MATERIALIZED_ADD`
  - 或 `A64_PENDING_CC_MATERIALIZED_SUB`

这部分应与 register-form / immediate-form materialized producer 保持一致。

## `B.cond` 路径边界

现有 `do_addsub_ext()` 里已经有：

- `SUBS xzr, ..., <ext> -> future B.cond`

这条 compare-to-branch 路径已经稳定，所以这一步必须继续保持：

- 若命中 future `B.cond`，优先保留原来的 bcond-only record
- 只有未命中 `B.cond` 时，才继续判断相邻 plain `SBC`

这样可以避免把已经稳定的 branch fast path 跟新的 arithmetic direct path 搅在一起。

## consumer / backend 设计

这一步尽量不改 consumer 主体逻辑：

- `a64_try_emit_x86_add_adc()` 继续处理 add-side consumer
- `a64_try_emit_x86_cmp_sbc()` 继续处理 sub-side consumer

consumer 看到的仍然是：

- `pending_cc.kind`
- `pending_cc.cc_op`
- `pending_cc.lhs`
- `pending_cc.rhs`

因为 ext rhs 已经是 live temp，所以：

- 不需要 immediate-form 那种 compare-like const 物化分支
- 不需要新增 ext-capable backend opcode

## 测试与验证

### correctness

至少补四类 focused coverage：

1. `adc-sbc-host-direct`
   - 增加 ext-form guest case
   - 断言 x86 host codegen 真的命中 direct path
2. ext-form `B.cond` 回归
   - 必须补一个 `SUBS xzr, ..., <ext> -> B.cond` 的 codegen / 语义保护用例
   - 目标不是验证新 direct path，而是防止 future-branch 与 adjacent-consumer
     的判定顺序写错，误伤现有 `cmp+jcc` 收益
3. `nzcv-status4`
   - 增加 ext-form compare-like 与 materialized 语义覆盖
4. `adcsbc-bench`
   - 新增真正使用 `<ext>` producer 的 dedicated mode

### benchmark 口径

不能直接拿现有 register-form mode 代替 ext-form。

建议新增清晰的 `_ext` mode，例如：

- `cmnadc64_ext`
- `cmnadc32_ext`
- `addsadc64_ext`
- `addsadc32_ext`
- `cmpsbc64_ext`
- `cmpsbc32_ext`
- `subsbc64_ext`
- `subsbc32_ext`

benchmark 里要确保：

- guest 确实走 `ADD/SUB (extended register)` 编码
- 不是把扩展结果预先算到通用寄存器里，再落回 register-form

### perf hard gate

和前几步保持同一标准：

- same tree
- same binary
- 只切对应 env gate
- 以 dedicated `_ext` benchmark mode 做 same-binary A/B

至少要 spot-check：

- `cmnadc64_ext`
- `cmnadc32_ext`
- `addsadc64_ext`
- `addsadc32_ext`
- `cmpsbc64_ext`
- `cmpsbc32_ext`
- `subsbc64_ext`
- `subsbc32_ext`

其中 32-bit compare-like 两项：

- `cmnadc32_ext`
- `cmpsbc32_ext`

要额外做更长一档的确认轮次，避免把短跑噪音误判成可收结论。

## 风险

### 风险 1：误伤现有 `SUBS xzr,<ext> -> B.cond`

这是这一步最需要明确保护的现有收益点。

如果把 future-branch 与 adjacent-consumer 的预判顺序处理错了，
很容易让已经稳定的 `cmp+jcc` 路径出现 code-shape 回退。

### 风险 2：benchmark 假命中

ext-form benchmark 如果把扩展值预先算进普通寄存器，
就会测成 register-form，而不是这一步真正的 producer。

因此 `_ext` benchmark 必须显式使用 extended-register 指令编码。

### 风险 3：32-bit 扩展路径的 host code shape 可能比 64-bit 更敏感

虽然 ext-form 没有 immediate 的 constant 胶水问题，但 32-bit 路径仍然可能因为：

- 额外的 zero-extend
- host register pressure
- split-flags capture 顺序

而比 64-bit 更敏感，所以 32-bit 必须独立做 A/B。

如果 32-bit compare-like ext path 出现稳定负回退，这一步优先按“代码侧范围收窄”
处理，也就是：

- 在 producer 命中条件里裁掉单一亏损路径
- 保留同家族里其余仍然正收益的 reg / imm / ext 子路径

这里说的“单一路径回滚”不是新增 per-subpath env gate，而是和
`CMN32 #imm -> ADC32` 一样，按实现范围收窄 accepted scope。

## 完成标准

这一步完成的标准是：

- extended-form `CMN/CMP/ADDS/SUBS -> ADC/SBC` 在 x86 host 上能命中 direct path
- focused correctness 全绿
- dedicated `_ext` benchmark 能证明没有稳定语义错误
- perf hard gate 没有出现稳定负回退

如果 correctness 过了，但某一条 ext-form 子路径出现稳定负收益，
则这一步按已有策略处理：

- 优先通过代码侧 scope narrowing 裁掉单一亏损路径
- 不把整档 ext-form 一起撤回

补充约束：

- `SUBS xzr,<ext> -> B.cond` 的现有 fast path 必须保持有专门 regression 保护
- `cmnadc32_ext` / `cmpsbc32_ext` 只有在短跑和长跑都不过线时，才允许被收窄
