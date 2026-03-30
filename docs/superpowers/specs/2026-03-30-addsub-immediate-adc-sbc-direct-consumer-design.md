# immediate-form `ADDS/SUBS/CMN/CMP -> ADC/SBC` 直通设计

**日期：** 2026-03-30

**状态：** 草案已确认，可进入实现计划

## 目标

在现有 register-form 相邻直通已经跑通的基础上，把 same-TB adjacent 的
immediate-form producer 也纳入同一条优化链路：

- `CMN / ADDS xzr, rn, #imm -> plain ADC`
- `CMP / SUBS xzr, rn, #imm -> plain SBC`
- `ADDS rd, rn, #imm -> plain ADC`
- `SUBS rd, rn, #imm -> plain SBC`

目标仍然是 x86 host 上的 carry/borrow 直通：

- producer 负责把 live host `CF` 留在当前 lowering 链上
- consumer 直接发 plain host `adc/sbb`
- producer/consumer 命中后仍然恢复 canonical raw-flags state

这一步要尽量复用当前已经稳定的：

- `pending_cc.kind`
- `a64_try_emit_x86_add_adc()`
- `a64_try_emit_x86_cmp_sbc()`
- 现有 env gate 与 focused test/perf 口径

## 为什么现在做这一步

当前 register-form 已经覆盖：

- compare-like `CMP/SUBS(xzr) -> SBC`
- compare-like `CMN/ADDS(xzr) -> ADC`
- materialized `ADDS rd -> ADC`
- materialized `SUBS rd -> SBC`

而 `do_addsub_imm()` 还明显停在较早的状态：

- 只做了 `SUBS xzr,#imm -> B.cond` 的 lazy compare 预判
- 没有 immediate-form 相邻 `ADC/SBC` 预判
- 没有 immediate-form materialized producer 的 pending-cc 记录

也就是说，当前相邻 arithmetic direct-consumer 的空白位已经主要集中在
immediate-form 上了。

## 当前实现约束

这一步虽然大方向和 register-form 很像，但 immediate-form 有一个真实差异：

- `a->imm` 进入 translator 时已经是展开后的常量
  - `@addsub_imm12` 会先做 `<< 12`
  - `do_addsub_imm()` 拿到的是最终的 `a->imm`
- 当前 compare-like fused op
  - `x86_cmp_sbb_capture_cmp_rawflags`
  - `x86_add_adc_capture_add_rawflags`
  在 `tcg/tcg.c` 里要求输入不是 constant
- 这意味着 `CMP/CMN #imm` 这类 compare-like immediate producer
  不能像 register-form 那样直接把 `tcg_constant_i64(a->imm)` 原样塞给 fused op

这条约束不会影响 materialized producer：

- `ADDS/SUBS rd,#imm` 本身仍然可以继续走现有 `gen_add_CC()` / `gen_sub_CC()`
- consumer 侧 plain `ADC/SBC` 只吃 live `CF`，不需要再看到 producer 的 `#imm`

真正需要额外处理的是 compare-like immediate producer。

## 非目标

这一步不做：

- `do_addsub_ext()` 或其他 non-immediate producer
- gap / cross-TB 扩展
- 新 env gate
- 改 backend opcode matrix 的大重构
- 一次性泛化到所有 immediate arithmetic/logical producer
- 直接引入“支持 immediate 的 compare-like fused backend op”新系列

## 候选方案与取舍

### 方案 1：只做 materialized immediate producer

范围收窄为：

- `ADDS rd,#imm -> ADC`
- `SUBS rd,#imm -> SBC`

优点：

- 最稳
- 不碰 compare-like immediate 的 constant 约束

缺点：

- 留下 `CMN/CMP #imm` 这块明显空白
- 很快还要再做第二轮实现

这一步不选它作为最终方案。

### 方案 2：完整 immediate-form 前端扩展，compare-like immediate 先物化为 temp

范围覆盖：

- compare-like immediate producer
- materialized immediate producer

其中 compare-like immediate producer 的 `#imm` 在 translator 里先物化成 temp，
再喂给现有 fused op。

优点：

- 能一次把 immediate-form 这档收完整
- consumer/backend 大部分可以直接复用现有实现
- 不需要现在就新增一套 immediate-capable backend outop

缺点：

- compare-like immediate 会多一条 temp materialization 胶水
- 需要明确保护现有 `B.cond` immediate path，不要顺手引入回退

这一步采用此方案。

### 方案 3：新增 immediate-capable compare-like fused backend op

也就是给：

- `cmp+sbb capture`
- `add+adc capture`

各自再做 `ri`/`rri` 变体，直接把 `#imm` 带到 backend。

优点：

- 从 host 代码形状上最干净
- 避免 compare-like immediate 的 temp materialization

缺点：

- 改动面从前端扩展升级为 backend opcode 扩容
- review、验证、约束设计都会明显更重
- 当前还没有证据证明方案 2 的 temp materialization 会成为真实瓶颈

这一步不采用。

## 选定方案

### 总体思路

让 `do_addsub_imm()` 在结构上尽量对齐现有 `do_addsub_reg()`：

- producer 侧增加相邻 plain `ADC/SBC` 预判
- compare-like immediate 命中时跳过旧的 flags lowering
- materialized immediate producer 继续走现有 `gen_add_CC()` / `gen_sub_CC()`
- 命中后都通过 `pending_cc.kind + cc_op` 接到现有 consumer helper

也就是说，这一步的核心仍然是“把 immediate-form producer 接上现有骨架”，
而不是另起一套实现。

## producer 设计

### 1. compare-like immediate producer

覆盖：

- `SUBS xzr, rn, #imm` / `CMP rn, #imm`
- `ADDS xzr, rn, #imm` / `CMN rn, #imm`

命中条件：

- same TB
- next guest insn 与当前 producer 真正相邻
- next insn 是 plain `SBC` 或 plain `ADC`
- 仍然受现有开关控制：
  - `CMP/SUBS(xzr) -> SBC` 走 `QEMU_A64_DISABLE_CMP_SBC_DIRECT`
  - `CMN/ADDS(xzr) -> ADC` 走 `QEMU_A64_DISABLE_ADD_ADC_DIRECT`

lowering 方案：

- 命中后不发旧的 `gen_add_CC()` / `gen_sub_CC()`
- 记录 `pending_cc.kind = A64_PENDING_CC_REWINDABLE_CMP`
- 记录 `lhs = tcg_rn`
- 记录 `rhs = tcg_imm_live`
  - 这里的 `tcg_imm_live` 不是裸 `tcg_constant_i64(a->imm)`
  - 而是先物化到一个 temp，再把这个 temp 记进 `pending_cc`

为什么要这样做：

- 当前 compare-like fused op 不接受 constant 输入
- 先物化成 temp，可以不改 backend op 约束，直接复用现有 consumer emitter

### 2. materialized immediate producer

覆盖：

- `ADDS rd, rn, #imm -> plain ADC`
- `SUBS rd, rn, #imm -> plain SBC`

命中条件：

- same TB
- next guest insn 真正相邻
- next insn 是 plain `ADC` 或 plain `SBC`
- 仍然受现有开关控制：
  - add 家族走 `QEMU_A64_DISABLE_ADD_ADC_DIRECT`
  - sub 家族走 `QEMU_A64_DISABLE_SUB_SBC_DIRECT`

lowering 方案：

- producer 继续走现有 `gen_add_CC()` / `gen_sub_CC()`
- 紧接着记录：
  - `pending_cc.kind = A64_PENDING_CC_MATERIALIZED_ADD`
  - 或 `A64_PENDING_CC_MATERIALIZED_SUB`
- consumer 侧继续只用 live host `CF`

这部分和 register-form materialized producer 的模式应保持一致。

## immediate 物化策略

### 不改变现有 bcond-only immediate 路径

`SUBS xzr,#imm -> B.cond` 现有路径已经稳定，而且它的 host emitter 本身支持
reg/imm 形态，所以这一步不应该为了统一实现而把它一起改成 temp materialization。

也就是说：

- 只命中 future-`B.cond` 时，继续保留现有 constant-based record 方式
- 只命中相邻 `ADC/SBC` compare-like direct path 时，才额外物化 `#imm`

这样能把改动面控制在新的优化路径内，不扰动已经验证过的 `cmp+jcc` 收益。

### compare-like immediate 的 temp 只服务于 fused consumer

这条 temp materialization 不是为了架构语义需要，而是为了满足当前
backend fused op 的约束。

因此这一步不把它抽象成通用机制，只在 immediate compare-like direct path
里局部使用。

如果后续 perf 证明这段胶水在 immediate compare-like benchmark 上明显吃亏，
再单独评估是否值得上 immediate-capable backend outop。

## consumer / backend 设计

这一步尽量不改 consumer 主体行为：

- `a64_try_emit_x86_add_adc()` 继续负责 `ADC`
- `a64_try_emit_x86_cmp_sbc()` 继续负责 `SBC`

consumer 看到的依然是：

- `pending_cc.kind`
- `pending_cc.cc_op`
- `pending_cc.lhs/rhs`

因此：

- materialized immediate producer 不需要新 consumer 逻辑
- compare-like immediate producer 的关键只是把 `rhs` 变成一个 live temp

这一步默认不新增 backend opcode。

## 数据流与控制流

### `do_addsub_imm()` 预期新增的判断面

建议和 register-form 对齐出这几类布尔状态：

- `lazy_bcond_cmp`
- `lazy_sbc_cmp`
- `lazy_adc_add`
- `materialized_sbc_sub`
- `materialized_adc_add`

行为上：

- compare-like immediate producer 命中 `lazy_*` 时，跳过旧 flags lowering
- materialized immediate producer 命中 `materialized_*` 时，保留旧 lowering
- 命中后统一走 `pending_cc` record

### `cc_op` 与 `kind`

沿用当前已稳定模型：

- compare-like add producer:
  - `kind = A64_PENDING_CC_REWINDABLE_CMP`
  - `cc_op = A64_X86_CC_ADD64/ADD32`
- compare-like sub producer:
  - `kind = A64_PENDING_CC_REWINDABLE_CMP`
  - `cc_op = A64_X86_CC_SUB64/SUB32`
- materialized add producer:
  - `kind = A64_PENDING_CC_MATERIALIZED_ADD`
- materialized sub producer:
  - `kind = A64_PENDING_CC_MATERIALIZED_SUB`

这样 consumer 侧就不需要再分出 “immediate producer” 的新 kind。

## 测试与验证

### correctness

至少补三类 focused coverage：

1. `adc-sbc-host-direct`
   - 增加 immediate-form guest case
   - 验证 x86 host codegen 确实命中 direct path
2. `nzcv-status4`
   - 增加 immediate-form compare-like 与 materialized 语义覆盖
3. `adcsbc-bench`
   - 新增 immediate-form dedicated mode

### benchmark 口径

现有 benchmark mode 只覆盖 register-form：

- `cmnadc64/32`
- `addsadc64/32`
- `subsbc64/32`

它们不能代表新的 immediate-form 收益。

因此需要新增 dedicated mode，建议使用清晰的 `_imm` 后缀，例如：

- `cmnadc64_imm`
- `addsadc64_imm`
- `subsbc64_imm`
- `cmnadc32_imm`
- `addsadc32_imm`
- `subsbc32_imm`

### perf hard gate

和前几步保持同一标准：

- same tree
- same binary
- 只切对应 env gate
- 以 dedicated immediate-form benchmark mode 做 A/B

最少要 spot-check：

- `cmnadc64_imm`
- `cmnadc32_imm`
- `addsadc64_imm`
- `addsadc32_imm`
- `subsbc64_imm`
- `subsbc32_imm`

如果 compare-like immediate 的 temp materialization 带来稳定负收益，
就要停下来单独判断：

- 是不是只 materialized producer 值得先收
- 还是要上 immediate-capable backend outop

## 风险

### 风险 1：compare-like immediate 的 temp 胶水吃掉收益

这是这一步最真实的性能风险。

当前设计默认它不会比完全重做 backend outop 更糟，但这不是先验事实，
必须靠 dedicated immediate benchmark 证明。

### 风险 2：误伤现有 `SUBS xzr,#imm -> B.cond`

如果为了统一实现把现有 bcond-only immediate path 也一起改写，
很容易引入既没有必要、又难第一时间看出来的 perf 形状变化。

所以这一步必须把 bcond-only 路径和新的 `ADC/SBC` direct path 明确分开。

### 风险 3：32-bit immediate compare-like 可能和现有 `cmnadc32` 一样更敏感

32-bit 路径通常更容易被额外的寄存器胶水放大成本，
所以 immediate 物化后的 i32 路径要单独盯。

## 完成标准

这一步完成的标准是：

- immediate-form `CMN/CMP/ADDS/SUBS -> ADC/SBC` 在 x86 host 上能命中 direct path
- focused correctness 全绿
- dedicated immediate-form benchmark 能证明没有稳定错误
- 若实现被收下，还需要通过 “无稳定性能负回退” 这条 hard gate

如果 correctness 过了，但 immediate compare-like 的专用 benchmark 显示稳定负收益，
则不直接视为完成，而是回到方案裁剪：

- 先只收 materialized immediate producer
- 或者单独设计 immediate-capable backend outop

