# `ADCS/SBCS -> ADC/SBC/ADCS/SBCS` 直通设计

**日期：** 2026-04-01

**状态：** 草案已确认，可进入实现计划

## 目标

在当前 `ADDS/SUBS -> ADCS/SBCS` 已经收口后，继续把同一条 arithmetic
carry/borrow 链往前推一格：

- `ADCS -> ADC`
- `ADCS -> ADCS`
- `SBCS -> SBC`
- `SBCS -> SBCS`

这一步的核心不是扩 compare-like producer，而是让已经被 consumer 自身重新生成的
host `CF` 再被下一条 arithmetic consumer 直接使用。

目标范围刻意收窄为：

- AArch64 guest on x86 host
- same-TB
- truly-adjacent producer / consumer
- 先以 register-form focused correctness 为主
- 第一批只做 same-width 链
  - `64 -> 64`
  - `32 -> 32`

## 为什么现在做这一步

当前已完成的 arithmetic flags 直通链条是：

- `CMN/CMP/ADDS/SUBS -> plain ADC/SBC`
- `ADDS/SUBS -> ADCS/SBCS`

而缺口正好落在：

- `ADCS/SBCS` 自身已经能产出正确 raw flags
- 但这些 flags 目前还不能继续被下一条 `ADC/SBC/ADCS/SBCS` 当作 direct producer 使用

也就是说，当前已经具备：

- consumer 后 raw-flags capture
- `A64_X86_CC_ADC* / SBC*` raw-state
- live host `CF` 在 helper 结束时仍然存在

所以这一步是当前 arithmetic 直通线里最自然、连续性最高的一条扩展。

## 为什么不先重开 `CMN/CMP -> ADCS/SBCS`

这一步明确不重开 compare-like `CMN/CMP -> ADCS/SBCS`。

原因不是那条路径永远不能优化，而是：

- 它不满足当前这条 live-`CF` materialized 直通假设
- 它更像“seed carry/borrow 再进入 consumer”的 specialized fallback 优化
- 如果现在把它和 `ADCS/SBCS as producers` 混在一起，设计会失焦

当前优先级更高的，是把已经 materialized 的 arithmetic producer 链条继续延长。

## 非目标

这一步不做：

- `CMN/CMP -> ADCS/SBCS`
- gap / cross-TB 扩展
- 非 x86 host
- mixed-width producer / consumer chaining
  - `ADCS32 -> ADC64`
  - `ADCS64 -> ADC32`
  - `SBCS32 -> SBC64`
  - `SBCS64 -> SBC32`
- floating-point compare / consumer
- `B.cond` branch 直通
- 新的 perf 口径设计
- 一次性重构全部 `pending_cc.kind`

## 候选方案与取舍

### 方案 1：只做 `ADCS/SBCS -> ADC/SBC`

优点：

- plain consumer 不写 flags，后处理更接近现有 `a64_try_emit_x86_add_adc()` /
  `a64_try_emit_x86_cmp_sbc()`
- 风险最低

缺点：

- 很快还要再做一轮 `ADCS/SBCS -> ADCS/SBCS`
- 对多精度 setflags arithmetic 链的覆盖不完整

这个方案适合作为第一批 rollout，但不适合作为完整设计边界。

### 方案 2：设计覆盖全部四条链，但实施分阶段

覆盖：

- `ADCS -> ADC`
- `ADCS -> ADCS`
- `SBCS -> SBC`
- `SBCS -> SBCS`

实施分两批：

1. phase A1：先落 `ADCS/SBCS -> ADC/SBC`
2. phase A2：再落 `ADCS/SBCS -> ADCS/SBCS`

优点：

- 设计边界一次说明白
- 实现风险仍可按批次收窄
- 测试与 helper 设计不会来回改方向

缺点：

- 需要在 spec 里提前明确 plain consumer 与 setflags consumer 的后处理差异

这一步采用此方案。

### 方案 3：直接把所有 arithmetic producer 统一成一套“大一统 carry-chain framework”

优点：

- 长期结构最整齐

缺点：

- 会把当前已稳定的 helper 和 `pending_cc` 判断一起翻新
- 抽象维度太早，风险和收益不匹配

这一步不采用。

## 选定方案

### 总体思路

把 `ADCS/SBCS` 视为新的 **materialized arithmetic producer**。

关键点不是新增一个完全不同的 producer 家族，而是承认：

- `ADCS` 结束后，host `CF` 和 raw flags 表示的是 **ADC-style** producer
- `SBCS` 结束后，host `CF` 和 raw flags 表示的是 **SBC-style** producer

这意味着：

- producer 记录逻辑要能识别“当前 setflags arithmetic 指令的 next insn 是
  `ADC/SBC/ADCS/SBCS`”
- consumer helper 不能只接受 `ADD* / SUB*`
- 需要同时理解 `ADC* / SBC*` 这两类 producer raw-state

### Producer 建模

这一步不强制新增新的 `pending_cc.kind`，但要求实现上明确区分两层信息：

1. **producer family**
   - add-like
   - sub-like
2. **producer raw-state**
   - `A64_X86_CC_ADD*`
   - `A64_X86_CC_ADC*`
   - `A64_X86_CC_SUB*`
   - `A64_X86_CC_SBC*`

设计建议：

- 保持 `MATERIALIZED_ADD` / `MATERIALIZED_SUB` 作为 kind
- 通过 `cc_op` 区分 `ADD` 与 `ADC`、`SUB` 与 `SBC`

这样能复用当前 materialized producer 判断，不需要为这一步再加新的 kind。

### Producer 触发条件

当前 `do_adc_sbc()` 的 setflags 分支在执行 `ADCS/SBCS` 后，只负责完成当前
consumer 的语义，并不会把自己再记录成下一条 producer。

这一步要求：

- 当当前指令是 `ADCS`
  - next insn 若是 truly-adjacent `ADC` 或 `ADCS`
  - 记录 add-side materialized producer
- 当当前指令是 `SBCS`
  - next insn 若是 truly-adjacent `SBC` 或 `SBCS`
  - 记录 sub-side materialized producer

phase A1 可先只认 plain consumer：

- `ADCS -> ADC`
- `SBCS -> SBC`

phase A2 再把 setflags consumer 打开：

- `ADCS -> ADCS`
- `SBCS -> SBCS`

在当前设计里，`rd != 31` 约束同样适用于 phase A1 和 phase A2。
`rd == 31` 的 `SBCS xzr` / `ADCS xzr` 不在这一轮 `ADCS/SBCS as producers`
范围里。

### 与现有 `SBCS xzr -> future B.cond` 的优先级

这一步必须明确保留现有 compare-for-branch 路径的语义。

规则：

- 当当前指令是 `SBCS xzr,...` 且当前已有 `future B.cond` lazy-branch 命中条件成立时
  - **现有 compare-for-`B.cond` 路径优先**
  - 不在这一步同时把它记录成 arithmetic-chain producer
- `ADCS/SBCS as producers` 的第一批 rollout 只覆盖：
  - `rd != 31`

这样可以避免把现有 branch compare alias 语义和 arithmetic chaining 混在同一轮里。

### Consumer 设计

#### 1. `ADCS -> ADC`

可直接复用 add-side plain helper 的形状，但 acceptance 要从：

- `cc_op == ADD32/ADD64`

扩成：

- `cc_op == ADD32/ADD64`
- 或 `cc_op == ADC32/ADC64`

语义上这没有问题，因为 plain `ADC` 只关心 carry-in，不关心 producer 自己是否也带了 carry 输入。

命中后行为仍然是：

- 直接吃 live host `CF`
- 执行 host `adc`
- 结束后恢复 producer raw-state，而不是保留 consumer raw-state

#### 2. `SBCS -> SBC`

与 add-side 对称：

- 现有 plain `SBC` helper 接受 `SUB*`
- 这一步扩成同时接受 `SUB*` / `SBC*`

命中后：

- 直接吃 live host borrow chain
- 执行 host `sbb`
- 结束后恢复 producer raw-state

#### 3. `ADCS -> ADCS`

这是 setflags consumer 接 setflags producer。

命中条件与当前 `ADDS -> ADCS` 相同，但 producer `cc_op` 扩成：

- `ADD*`
- `ADC*`

命中后：

- 直接吃 live host `CF`
- 发 host `adc`
- capture consumer raw flags
- 保留 consumer raw-state，不恢复 producer

#### 4. `SBCS -> SBCS`

与 add-side 对称：

- producer `cc_op` 扩成 `SUB*` / `SBC*`
- 命中后保留 consumer raw-state

## Raw Flags / State Model

这一块必须明确，因为它是 plain consumer 与 setflags consumer 的根本差异。

### Plain consumer (`ADC/SBC`)

consumer 不写 architectural flags，所以：

- producer 之后的 canonical raw-state 必须保留
- consumer 只临时借用 live host `CF`
- helper 结束后恢复 producer raw-state

### Setflags consumer (`ADCS/SBCS`)

consumer 自己就是新的 flags producer，所以：

- helper 结束后必须保留 consumer raw-state
- 不恢复 producer raw-state

这一步的设计要求，是让 `ADCS/SBCS as producers` 同时适配这两类后处理。

## 测试设计

### Phase A1 focused tests

最先补的 focused coverage：

- `ADCS64 -> ADC64`
- `ADCS32 -> ADC32`
- `SBCS64 -> SBC64`
- `SBCS32 -> SBC32`

验证内容：

- 功能结果
- consumer 后 raw-state 没有破坏 producer flags
- `out_asm` 中无额外 carry/borrow decode glue

### Phase A2 focused tests

第二批：

- `ADCS64 -> ADCS64`
- `ADCS32 -> ADCS32`
- `SBCS64 -> SBCS64`
- `SBCS32 -> SBCS32`

验证内容：

- 功能结果
- consumer 后 `MRS NZCV`
- direct helper 确实命中

### 回归保护

必须额外确认：

- 当前 `ADDS/SUBS -> ADCS/SBCS` 不回退
- 当前 plain `ADC/SBC` direct path 不回退
- `CMN/CMP -> ADCS/SBCS` 仍保持 fallback，不被误打开
- `SBCS xzr -> future B.cond` 现有路径保持优先级，不被 arithmetic chaining 抢走
- mixed-width chaining 仍保持 fallback，不被误打开

## 风险点

1. `ADC* / SBC*` producer raw-state是否与 plain helper 的 restore 逻辑完全兼容
2. `pending_cc` 记录时机是否会与当前 `SBCS xzr -> future B.cond` 产生优先级冲突
3. setflags producer 再作为 producer 时，tracing / `consumer` bookkeeping 是否一致

## 推荐实施顺序

1. 先做 phase A1：`ADCS/SBCS -> ADC/SBC`
2. focused verify + codegen guard 稳住
3. 再做 phase A2：`ADCS/SBCS -> ADCS/SBCS`
4. 不把 `CMN/CMP -> ADCS/SBCS` 混进这一轮
