# Compare-like Producer Sidecar Shrink Design

**日期：** 2026-04-10

**状态：** 已确认方向，待实现计划

## 目标

在 `CCMP/FCCMP`、plain gap `B.cond`、plain gap `CSEL/CS*`、plain gap
`ADC/SBC` 都已经切到 current `RAW/SPLIT` main representation 之后，
继续收缩旧 `pending_cc` sidecar 的职责：

- plain downstream case 不再为“也许会命中”的旧 pairing 额外记账
- 只有真正有价值的 adjacent specialized shape 才继续保留 sidecar
- 把 miss-case 进一步拉向“直接沿 main representation 前进”

这一步的目标不是删除所有 direct-path，也不是扩大新的 direct helper；
而是把旧 sidecar 从“主线机制”继续压缩成“少数窄 fast path 的附加机制”。

## 当前背景

截至 `2026-04-10`，当前分支已经具备下面这个结构：

- `CCMP/FCCMP` 读取当前 main representation
- plain gap `B.cond` 读取当前 main representation
- plain gap `CSEL/CS*` 读取当前 main representation
- plain gap `ADC/SBC` 读取当前 main representation

也就是说，plain consumer 侧的主迁移已经基本完成。

但 producer 侧仍然残留一个老问题：

- compare-like producer 依然会在不少 plain downstream shape 上记录
  `pending_cc`
- 即使这些 downstream shape 最终已经不再 consume 旧 producer
- sidecar 记录因此容易退化成 miss-case 下的纯 bookkeeping

这和当前 main-representation 路线的目标是冲突的。

## 问题陈述

当前系统里最容易继续拖低 miss-case 的，不再是“缺某个 plain consumer”。
真正剩下的问题是：

- producer 侧仍把 sidecar 记录当作默认行为
- downstream 其实已经更常直接读取 current `RAW/SPLIT`
- 因此一部分 `pending_cc` 记录已经不再是主语义所需，而只是旧结构惯性

如果这部分不继续收缩，那么：

- high-hit adjacent path 仍然能快
- 但 low-hit / non-adjacent plain path 仍会为 sidecar 付账

## 非目标

这份设计不做：

- 一次性删除全部 `pending_cc`
- 重写整条 producer-chaining 体系
- 把所有 adjacent specialized path 都并入通用主表示
- 新增更多 direct helper 或扩大新的 pairwise 命中表
- 引入运行时动态策略或 profile-guided 开关

## 候选方案

### 方案 1：继续保留现状，优先扩更多 specialized path

优点：

- 命中现有窄 fast path 时仍然可以继续抬高峰值

缺点：

- sidecar 继续当默认机制
- miss-case 不会继续改善
- 方向上会重新偏回“靠 pairing 命中赚钱”

不采用。

### 方案 2：一次性移除 compare-like producer 的 `pending_cc`

优点：

- 结构最干净
- miss-case 最容易彻底瘦身

缺点：

- 风险太大
- 会直接损失已有 adjacent rechain / specialized fast path 收益
- 很难在一刀里验证边界是否收得正确

不采用。

### 方案 3：按 downstream 形状收紧 sidecar，只给 adjacent specialized path 留口子

核心思路：

- plain downstream case：只发布当前 `RAW/SPLIT` main representation
- adjacent specialized shape：继续允许 `pending_cc` record/consume
- 让 sidecar 从默认机制退化成少数高价值场景的局部加速层

优点：

- 能继续改善 miss-case
- 风险可控
- 保留已有高价值 adjacent fast path

采用此方案。

## 选定方案

### 1. compare-like producer 的默认语义调整

第一阶段聚焦：

- `CMP`
- `CMN`
- `SUBS rd == xzr`
- `ADDS rd == xzr`

这些 producer 在面对 plain downstream shape 时：

- 不再把 sidecar record 当默认行为
- 当前 flags 主语义只通过 `RAW/SPLIT` main representation 向后传递

### 2. 保留 sidecar 的形状

第一阶段明确保留的，是仍然有清晰收益的 adjacent specialized path：

- truly adjacent compare-like -> `ADCS/SBCS`
- truly adjacent compare-like reseed / rechain shape
- 已有 focused evidence 明确证明仍有价值的 adjacent chain-positive 组合

这些路径继续允许：

- record old producer
- downstream consume old producer

### 3. 收紧 sidecar 的形状

第一阶段优先收紧的是 plain downstream case：

- plain gap `B.cond`
- plain gap `CSEL/CS*`
- plain gap `ADC/SBC`
- 以及已经显式改成 main-representation read 的 `CCMP/FCCMP`

这些路径的原则是：

- producer 如需正确性和后续消费，只发布 current `RAW/SPLIT`
- 不再仅仅为了历史 pairing 语义去 record 一个将来不会被 consume 的
  `pending_cc`

### 4. 迁移顺序

这一刀不宜全量并发推进，顺序应当是：

1. 先从 compare-like `CMP/CMN` 的 plain downstream case 开始
2. 再看 `SUBS/ADDS rd==xzr` 的 materialized-compare-like case
3. 最后才考虑 promoted `CCMP/CCMN` producer 链上的 sidecar 收缩

原因是第一步边界最清楚，也最容易用现有 focused checker 改成精确红绿测试。

## 测试与验证策略

### focused checks

这一步的 focused checker 原则不再是“有没有 record pending”，而是：

- 对 plain downstream case：
  - 允许 no-record
  - 即使 record，也必须断言 downstream 不再 consume 它
- 对 adjacent specialized path：
  - 继续保留原来的 `use/retire` 断言

第一批重点检查：

- compare-like -> plain gap `B.cond`
- compare-like -> plain gap `CSEL/CS*`
- compare-like -> plain gap `ADC/SBC`
- compare-like -> `CCMP/FCCMP`
- adjacent compare-like -> `ADCS/SBCS`

### shared regressions

- `nzcv-status4`
- `raw-ccop specialization`
- 现有 chain-focused checks

### SPEC smoke

继续沿用当前已经稳定的 `502/505/531/541/557 test` smoke 口径。

## 风险

### 1. 误删仍然有价值的 adjacent reseed 路径

如果边界收得过粗，会把已有峰值收益一起砍掉。

### 2. producer 仍然需要给 downstream 提供 durable main state

sidecar 收缩不能等于“不再发布当前 flags 主表示”；否则会把 plain
consumer 的新结构重新打坏。

### 3. checker 语义需要同步更新

如果 checker 仍然把“record pending”当成功标志，就会把这一步的正确方向
误判为回退。

## 成功标准

这一步完成后，应能看到：

- plain downstream case 对旧 `pending_cc` 的 consume 进一步减少
- adjacent specialized path 仍保持绿色
- `progress.md` 与知识库中的“下一步”从“再迁一个 plain consumer”
  转向“继续收缩 producer-side sidecar”

## 结论

当前最值得做的不是“再补一个 plain consumer”，而是把 compare-like
producer 的默认语义继续从 sidecar 迁到 main representation。

第一阶段应以 `CMP/CMN` 为切入口：

- plain downstream case 只走 current `RAW/SPLIT`
- adjacent specialized shape 继续保留 old pending contract

这条线最符合当前主表示重构的方向，也最直接针对 low-hit miss-case 的剩余
结构性负担。
