# Lazy Compare Design Phase 2

**日期：** 2026-04-01

**状态：** 草案已确认，可进入实现计划

## 目标

在当前相邻 compare-consumer 直通已经成型之后，设计下一阶段的
**bounded lazy compare state**，让 compare-like producer 的价值不再局限于
truly-adjacent consumer。

phase 2 的目标是设计，不是立即做语义 rollout。

要解决的问题是：

- compare-like producer 之后经常只隔着少量不会破坏 flags 语义的指令
- 当前只优化相邻路径，稍微隔开一点就退回 eager flags
- 我们需要一个能跨过 bounded gap-safe 指令、但又能严格 invalidation 的 lazy compare 模型

## 当前基础

这条线已经具备的前置条件：

- adjacent `CMP/SUBS(xzr) -> B.cond` 已优化
- adjacent compare-like producer 到 `CSEL/FCSEL/CCMP/FCCMP` 已优化
- `pending_cc` metadata 已从早期 compare-specific 状态收敛成更中性的 producer record
- phase 1 instrumentation 已完成，已有 `-d op` / TB summary 基础

也就是说，现在不是从零设计 lazy compare，而是在已有 pending producer 框架上
延长 compare-like producer 的有效寿命。

## 为什么现在做 phase 2 设计

如果继续只做 pairwise adjacent direct path，问题会越来越明显：

- producer x consumer x width x form 组合持续增长
- 很多真实热点只是“隔了一两条安全指令”，却仍然退回 eager flags
- 每加一条新 helper，都要新增新的 hard-coded oracle

lazy compare design 的价值，是把“compare-like producer 的信息能活多久”
这个根问题建模清楚。

## 非目标

phase 2 设计不做：

- 立即放开非相邻语义
- cross-TB lazy compare
- 修改非 compare-like arithmetic producer 的生命周期
- floating-point compare lazy state
- 全面替换现有 adjacent fast path
- 一次性设计完整全局 flags scheduler

## 核心设计问题

这份 spec 要先回答 4 个问题。

### 1. lazy compare record 的边界是什么

最小设计原则：

- 只覆盖 compare-like producer
  - `CMP`
  - `CMN`
  - `SUBS xzr,...`
  - `ADDS xzr,...`
- 不覆盖 materialized arithmetic producer
- 不改变当前 plain arithmetic direct-consumer 的行为

### 2. 哪些指令允许跨过去

phase 2 采用 **bounded gap-safe** 设计，而不是无限寿命 lazy state。

第一批 rollout 的 bound 直接固定为：

- `A64_CMP_PENDING_GAP_MAX == 8`

也就是说：

- 这一步不是把“bound 留给 plan 决定”
- 而是明确复用当前分支已经存在的 bounded-gap 上限

第一批 rollout 的 whitelist 也直接固定为：

- 复用当前 `a64_insn_is_cmp_gap_safe()` 允许的集合，**原样照搬**
- 不在这份 spec 中继续发明第二套 gap-safe 规则

也就是：

- `NOP`
- `MOVN/MOVZ/MOVK`
- `SBFM/BFM/UBFM`
- 不写 flags 的 `ADD/SUB immediate`
- 不写 flags 的 logical shifted-register
- 不写 flags 的 `ADD/SUB shifted-register`
- 不写 flags 的 `ADD/SUB extended-register`

第一批 rollout 明确不扩大 whitelist。

### 3. 哪些事件必须立即 invalidation

下列情况必须立即结束 lazy compare：

- 任意会写 architectural flags 的指令
- 任意不在 `a64_insn_is_cmp_gap_safe()` whitelist 内的指令
- translator 不再继续顺序发射当前 TB 的事件
  - page crossing
  - TB instruction limit / end
  - direct control-flow cut
  - 任何 `base.is_jmp != DISAS_NEXT` 的情形

这一步保持保守，不做“看起来也许安全”的宽放行。

### 4. consumer 如何消费 lazy compare

phase 2 不设计“一个 consumer helper 统一吃所有 lazy compare”。
仍然维持：

- one consumer family at a time
- 先证明一个 family 的 invalidation / consume / clear 逻辑成立

并且第一批 rollout target 直接固定为：

- `B.cond`

## 候选方案与取舍

### 方案 1：只加 instrumentation，不做更具体的 lazy-state 设计

优点：

- 风险最低

缺点：

- 这一步已经有 phase 1 instrumentation 了
- 继续停在只有计数没有模型，推进意义不大

不采用。

### 方案 2：bounded lazy compare record + 显式 invalidation

核心思路：

- producer 记录 compare operands 和 compare family
- 允许跨过有限集合的 gap-safe 指令
- consumer 命中时直接读取 lazy compare record
- 一旦出现未知或 flags-clobbering 指令，立即 invalidation

优点：

- 和现有 `pending_cc` 最连续
- 风险可控
- 能逐 consumer family rollout

缺点：

- 需要把 invalidation 规则写得非常清楚

这一步采用此方案。

### 方案 3：更激进的“lazy flags everywhere”

也就是把 raw/split/canonical flags 的整体产生时机都推迟。

优点：

- 潜在收益大

缺点：

- 当前太早
- 会把已经稳定的 arithmetic direct path 一起卷进去

不采用。

## 选定方案

### 数据模型

phase 2 继续复用现有 `pending_cc` 主结构，但赋予 compare-like producer 更长的
translation-time 生命周期。

已定稿的字段语义：

- `lhs / rhs`
  - compare-like producer operands
- `cc_op`
  - compare family identity（例如 add-like compare 或 sub-like compare）
- `kind == REWINDABLE_CMP`
  - phase 2 lazy compare 只作用于 compare-like producer
- `gap_insns`
  - 剩余允许跨过的 gap-safe 指令数
  - producer record 时初始化
  - 每跨过一条 gap-safe 指令递减
  - 到 `0` 后不再允许继续跨
- `valid`
  - 当前是否仍有可消费的 lazy compare record
- `keep`
  - 当前 insn 结束后是否允许 record 继续存活到下一条 insn
- `end`
  - 记录 producer 发射结束时的最后一个 TCG op
- `rewind`
  - phase 2 继续保留其“adjacent rewinding”语义
  - 不把它解释成跨 gap 的通用恢复手段

不建议在 phase 2 一开始就再扩很多新字段，优先复用现有 record。

### 生命周期规则

#### Record

在 compare-like producer 处记录 lazy compare state。

#### Carry across gap-safe insns

只要后续指令满足 gap-safe whitelist：

- 保留 `pending_cc`
- `gap_insns` 递减
- 不 eager materialize canonical compare flags

#### Consume

命中被支持的 consumer family 时：

- consumer 直接读取 `pending_cc`
- 完成消费
- 清除 `pending_cc`

对当前第一批 rollout 来说，supported consumer matching（即 `B.cond` 命中）
优先于 generic invalidation 检查；也就是说，真正命中的 `B.cond` 不会因为
“direct control-flow cut” 规则被误判成先失效。

#### Invalidate

一旦遇到：

- 非 gap-safe 指令
- 任何 flags writer
- TB 不连续边界

就立刻 drop `pending_cc`。

### 与现有 adjacent rewinding path 的优先级

当同一个 producer / consumer 组合同时满足：

- 当前已存在的 adjacent rewinding fast path
- 以及新的 bounded lazy compare 命中条件

则规则固定为：

- **adjacent rewinding fast path 优先**
- bounded lazy compare 只处理“非相邻但仍在 gap-safe bound 内”的情况

这样 phase 2 不会改变当前已经稳定的 adjacent fast path 行为。

## Rollout Strategy

phase 2 是设计阶段，但 rollout 顺序必须在 spec 里先定出来。

### Step 1: 先定义 invariants

必须写清楚：

- lazy compare 只适用于 compare-like producer
- materialized arithmetic producer 不受这次设计影响
- non-adjacent 优化永远不能改变 guest-visible NZCV / GPR / control flow
- unknown instruction 一律 invalidate，而不是“猜安全”

### Step 2: 第一批语义 rollout 固定为 `B.cond`

原因：

- `B.cond` 语义最单纯
- 验证面最窄
- 当前 adjacent branch fast path 已经成熟
- 可以最直接对照当前已有 branch line的正确性模型

### Step 3: 每批 rollout 都保留 focused observability

每一批都必须有：

- focused asm regression
- `out_asm` / `-d op` 证据
- TB summary / trace 证明 lazy state 的 record / carry / consume / drop 是符合预期的

## 风险点

1. whitelist 过宽会引入隐蔽语义 bug
2. invalidation 过慢会把 stale compare record 错喂给后续 consumer
3. invalidation 过严则收益不足，落地价值变小
4. 和现有 adjacent rewinding path 共存时，必须保证优先级可解释

## 当前结论

phase 2 最合适的状态是：

- **现在写 spec**
- **接下来写 plan**
- **第一批 implementation 固定为 `B.cond`**

不建议把“设计 + 多 consumer family rollout”合成一个计划。

## 第一批 acceptance matrix

| 类别 | 要求 |
|---|---|
| Positive hit | compare-like producer 与 `B.cond` 之间隔 1..8 条 gap-safe 指令时仍命中 |
| Bound | 第 9 条 gap-safe 指令后必须失效 |
| Unknown insn | 遇到非 whitelist 指令必须失效 |
| Flags writer | 遇到任意写 flags 指令必须失效 |
| Boundary | page crossing / TB end / control-flow cut 必须失效 |
| Precedence | truly-adjacent 命中时仍优先走现有 adjacent rewinding path |
