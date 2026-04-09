# Deferred Flags Main Representation Design

**日期：** 2026-04-09

**状态：** 已确认，可进入实现计划

## 目标

在当前 AArch64 guest on x86 host 的 NZCV 优化线上，设计一套新的
**deferred flags 主表示模型**，解决当前实验路径的核心问题：

- 命中 direct-path / chaining 时可以明显更快
- 不命中时却会因为旁路记录、覆盖、失效和回退而明显拖累

这份设计的目标不是继续放大 pairwise direct-path 的命中收益，而是：

- 保留同 TB 内 live host flags 的最热收益
- 让跨 TB 的 flags 状态成为一等主表示
- 让 miss-case 尽量贴近 clean 原生 QEMU 的下限
- 避免依赖复杂的运行时动态调优机制

## 问题陈述

当前实验树已经证明：

- compare/add/adc/logic 相关的 host-flags / raw-flags 直通在部分 workload 上有效
- 但当前模型本质上仍然是 `pending producer -> maybe consumer` 的旁路优化
- 一旦后续没有及时命中 direct consumer，额外 bookkeeping 很容易吃掉收益

这类回退的根因不是“还少支持了几个 consumer”，而是：

- 当前 raw / pending 信息并不是 guest flags 的主表示
- 它更像 sidecar
- sidecar 命中时赚很多
- sidecar 失效时往往仍然要回到原生 flags 路径

因此，真正需要解决的问题不是继续扩大命中表，而是：

- 如何让 flags 表示本身变成主路径的一部分
- 如何让不命中时仍然沿着一条稳定、低开销的路径前进

## clean 原生基线的关键观察

这份设计以 `/home/wangruoyu/qemu10.2_clean` 的原生 AArch64 TCG 路径为比较基线。

clean 原生 QEMU 的关键特点不是“频繁构造标准 NZCV”，而是：

- 把 guest flags 缓存在 `CF/VF/NF/ZF` 四个 split proxy 中
- 这四个字段不是标准化后的 canonical NZCV bit
- 它们是面向 producer 和 consumer 的中间代理表示

例如：

- `CF` 直接保存为 `0/1`
- `NF` 只有 bit 31 有意义
- `VF` 只有 bit 31 有意义
- `ZF` 常被当作零检测代理，而不是直接存标准 Z bit

这意味着 clean 原生的优势在于：

- producer 侧不急着做 canonicalization
- consumer 侧按需解释这些 proxy
- 显式读写 `NZCV` 时才打包 / 解包架构格式

因此，如果新的 deferred flags 方案只是：

- 在 TB 结束时把 host flags 打成 canonical `NZCV[31:28]`
- 下一个 TB 再拆开读

那么它很可能比 clean 原生更重。

## 当前实验树的关键观察

当前实验树已经额外引入了：

- `x86_raw_flags`
- `x86_cc_op`
- `x86_flags_valid`
- 一批 x86-specific 的 `capture_rawflags + jcc/cmov` 发射路径

这证明了另一件事：

- 对 x86-friendly producer，存在一种比 canonical NZCV 更适合跨指令消费的 raw-like 表示
- 这种表示在命中时的上限明显高于 clean 原生 split proxy

但当前实验路径的问题在于：

- raw-like 状态仍然主要服务于旁路消费
- 没有成为 flags 的主表示
- 因此 miss-case 下仍然可能双重付账

## 设计约束

这份设计明确接受以下约束：

- 同 TB 内的最热收益仍然优先来自 live host flags
- 不要求“跨 TB 继续保留真实 host flags”
- 跨 TB 只能保留语义等价的 durable state
- 不接受复杂的运行时自适应开关作为主方案
- 不接受“所有 consumer 在运行时动态判断当前 flags 表示”的状态机
- 不接受把 canonical packed NZCV 作为常态主表示

## 非目标

这份设计不做：

- 一次性覆盖所有 flags producer / consumer 组合
- 让所有 flags 状态都统一进 raw-like 表示
- 把所有显式 `NZCV` 访问都保留在 deferred 状态中
- 继续扩大基于 `pending_cc` 的 bounded-gap sidecar 体系
- 依赖 benchmark-specific 的启发式策略

## 候选方案

### 方案 1：继续扩大当前 `pending_cc/raw-capture` 旁路体系

优点：

- 改动连续
- 已有代码可以复用

缺点：

- 本质仍然是 sidecar
- 主要放大 hit-case 收益
- 无法根治 miss-case 明显拖累

不采用。

### 方案 2：以 canonical packed NZCV 为跨 TB 主表示

核心思路：

- 同 TB 内尽量吃 live host flags
- 跨 TB 时统一打包成标准 `NZCV[31:28]`
- consumer 统一从 packed bits 读取

优点：

- 语义统一
- 跨 TB 容易理解

缺点：

- consumer 每次都要 mask / shift / test
- 很可能比 clean 原生 split proxy 更重
- 无法充分利用 x86-friendly raw 表示

不采用。

### 方案 3：双主表示 deferred flags

核心思路：

- `LIVE_HOST` 只负责同 TB 内瞬时最热路径
- durable state 有两种主表示：
  - `DEFERRED_RAW`
  - `DEFERRED_SPLIT`
- `RAW` 适用于 x86-friendly producer
- `SPLIT` 适用于无法低成本保留 raw 语义的 flags 状态
- 显式 `NZCV` 访问时才 canonicalize

优点：

- 命中时仍保留 raw/live-host 优势
- 不命中时可贴近 clean 原生下限
- 不要求所有状态统一成一种表示

缺点：

- 需要表示切换规则清晰
- 需要 TB 级 specialization 以避免 runtime state machine

采用此方案。

## 选定方案总览

### 1. 三层表示

#### `LIVE_HOST`

语义：

- 当前 TB 内，最近一次 x86-friendly producer 刚刚在宿主生成了 live host flags
- 如果后续 consumer 足够近，直接消费 host flags

特点：

- 不是 durable state
- 不跨 TB
- 只是一种瞬时 codegen 机会

#### `DEFERRED_RAW`

语义：

- 当前 guest flags 由一份 raw-like durable state 表示
- 可跨 TB 保存和继续消费

第一版数据形态固定为：

- `raw_flags`
- `cc_op`
- `flags_rep = RAW`

不在第一版中引入更大的 producer descriptor。

#### `DEFERRED_SPLIT`

语义：

- 当前 guest flags 由 clean 原生风格的 split proxy 表示

第一版直接复用原生语义：

- `CF`
- `VF`
- `NF`
- `ZF`
- `flags_rep = SPLIT`

#### `CANONICAL_NZCV`

语义：

- 只有当架构明确要求 `NZCV[31:28]` 格式时才生成

不作为常态主表示。

### 2. 设计原则

- 不再把 raw-like 状态作为 pairwise sidecar
- `RAW` 和 `SPLIT` 都是一等主表示
- 同 TB 内优先尝试 `LIVE_HOST`
- 失败后不是“优化失败”，而是继续沿着 `RAW` 或 `SPLIT` 主表示前进

## 为什么不接受“TB 退出时统一同步到 split”

这条路看起来简单，但很多情况下会更重。

因为 clean 原生本来就是：

- producer 直接更新 split proxy

如果新方案变成：

- TB 内暂时保留 host flags
- TB 退出时再额外执行一次 `host -> split`

那么只要 workload 中经常“flags 活到 TB 结束”，这就可能比 clean 原生更贵。

因此本设计明确规定：

- 不要求 TB 退出时默认 `RAW -> SPLIT`
- TB 退出时保持当前主表示即可
- `RAW` 继续跨 TB 传播
- `SPLIT` 继续跨 TB 传播

## `DEFERRED_RAW` 的具体形态

第一版 durable raw 状态固定为：

- `raw_flags`
- `cc_op`

原因：

- 状态小
- 跨 TB 传递简单
- 当前实验树已经证明它足以支撑 ARM cond 判定
- x86 后端已经存在 capture raw flags 的发射支持

第一版明确不采用：

- `lhs/rhs`
- `carry_in`
- `producer_kind`
- `gap metadata`
- `chain depth`

等更大的 descriptor 字段。

这些字段适合 sidecar / pairing 优化，不适合作为 durable 主表示。

## producer 分类

### 进入 `DEFERRED_RAW` 的 producer

第一版包括：

- `CMP`
- `SUBS`
- `CMN`
- `ADDS`
- `ADCS`
- `SBCS`
- `ANDS`
- `BICS`
- `TST`
- 一部分可稳定映射到 raw-like 语义的 `CCMP/CCMN`

选择标准是：

- 能以低成本映射到 `raw_flags + cc_op`
- 后续 consumer 能直接从 raw 状态消费

### 进入 `DEFERRED_SPLIT` 的 producer

第一版包括：

- `MSR NZCV`
- 异常恢复 / helper 恢复相关路径
- `CFINV`
- `XAFLAG`
- `AXFLAG`
- 任何对现有 flags 做复杂布尔重写、但不适合 durable raw 的指令

### 关键规则

“不适合 `RAW`”不等于“什么都不做”。

正确做法是：

- 更新 split proxy
- 把 `flags_rep` 切到 `SPLIT`
- 后续 TB 按 `SPLIT` 传播

不能保留旧 raw 值并继续把它当成当前 flags。

## 指令分类：`transparent / consume / overwrite / materialize`

### `guest-transparent`

这类指令：

- 不读 guest flags
- 不写 guest flags

效果：

- `DEFERRED_RAW / DEFERRED_SPLIT` 继续有效
- `LIVE_HOST` 通常结束

例如：

- 不带 `S` 的普通算术 / 逻辑
- load/store
- 寄存器搬运
- 地址计算

### `consume-only`

这类指令：

- 只读当前 flags
- 不改当前主表示

第一版重点 consumer：

- `B.cond`
- `CSEL/CSINC/CSINV/CSNEG/CSET/CSETM`
- `ADC/SBC`

消费策略：

- 先尝试 `LIVE_HOST`
- 否则按当前主表示读取：
  - `RAW` consumer path
  - `SPLIT` consumer path

### `overwrite`

这类指令：

- 生成新的 flags
- 直接替换当前 flags 主表示

可能产生：

- `RAW -> RAW`
- `RAW -> SPLIT`
- `SPLIT -> RAW`
- `SPLIT -> SPLIT`

这些切换是翻译期状态更新，不是运行时状态机。

### `materialize`

这类路径：

- 需要架构格式 `NZCV`

例如：

- `MRS NZCV`
- 某些 helper / 异常边界
- 必须观察 canonical PSTATE bit layout 的路径

只在这些边界才进行 canonicalization。

## TB specialization

### 目标

避免运行时出现：

- `if RAW ... else if SPLIT ...`
- `UNKNOWN` 驱动的动态分流

### 入口状态

第一版只保留两种 durable TB 入口表示：

- `ENTRY_FLAGS_RAW`
- `ENTRY_FLAGS_SPLIT`

`LIVE_HOST` 不是入口状态。

### translator 行为

TB 初始化时，根据入口 tag 设定当前 translator flags state：

- `RAW`
- `SPLIT`

随后整块 TB 的 codegen 都按当前表示直接发射对应路径。

TB 内如果遇到新的 setflags producer，则在翻译期更新当前表示。

### TB 退出时的要求

TB 退出时只需：

- 保留当前 payload
- 写出最终 `flags_rep`

不要求默认执行：

- `RAW -> SPLIT`
- `RAW/SPLIT -> CANONICAL`

## consumer 读取路径

### `RAW` consumer path

第一版重点支持：

- `B.cond`
- `CSEL*`
- `ADC/SBC`

读取方式：

- 从 `raw_flags + cc_op` 直接判定 guest cond 或 carry
- 对 x86 host，优先继续落成 `jcc/cmov` 友好的路径

### `SPLIT` consumer path

这部分第一版尽量复用 clean 原生：

- `B.cond` 继续按 split proxy 判 cond
- `CSEL*` 继续按 split proxy 生成 cond
- `ADC/SBC` 继续从 `CF` 读取 carry
- `XAFLAG/AXFLAG/CFINV` 继续在 split proxy 上直接变换

### 第一版不追求的 `RAW` consumer

以下内容不作为第一版强目标：

- 完整 general form 的 `CCMP/CCMN` consumer+producer 链
- 所有 flags transform 在 `RAW` 上直接执行
- 所有显式 `NZCV` 访问都坚持不切表示

原因是这些点最容易让主线重新退化为复杂状态机。

## 为什么这能改善 miss-case

新方案的本质改变不是“更高命中率”，而是“更好的 miss 付账方式”。

当前 sidecar 模型的问题是：

- producer 先记录一份可能将来有用的旁路状态
- consumer 没命中时，这份记录的成本就很难回收

新方案中：

- producer 直接生成 flags 主表示
- consumer 默认读取当前主表示
- 没吃到 `LIVE_HOST` 只代表“没吃到最便宜的一层”
- 不代表 flags 优化整体失败

因此这条路的直接目标是：

- 把 miss-case 从“明显更差”压回“接近原生”

而不是先追求更高的峰值加速。

## 为什么这不是“运行时判断流程更重”

如果把这套模型实现成运行时状态机：

- 每条指令先判断当前表示
- 每个 consumer 再做 `RAW/SPLIT` 分派

那么它一定更重，不可接受。

因此本设计明确要求：

- 表示分类发生在翻译期
- `RAW/SPLIT` 选择尽量发生在 TB 入口
- 运行时只执行已专门化的那条路径

方案是否成立，关键不在分类本身，而在是否能尽量消灭 `UNKNOWN` 和 runtime representation dispatch。

## 前后端改动边界

### 只改前端能做到什么

只改前端，可以做出：

- 可工作的 deferred flags 主表示模型
- `RAW/SPLIT` 的 durable 切换
- 更清晰的语义生命周期

但如果目标是：

- 在 x86 host 上普遍比 clean 原生更快

只改前端通常不够。

### 为什么需要前后端协同

原生 clean 树的优势之一是：

- split proxy 对通用 TCG cond lowering 友好

当前实验树的优势之一是：

- raw-like 表示对 x86-specific `jcc/cmov/capture_rawflags` 发射友好

因此要让新的主表示模型既保住上限、又改善下限，需要：

- 前端把 `RAW/SPLIT` 都提升成一等主表示
- 后端继续支持 `RAW` 的低成本消费

也就是说：

- `SPLIT` 负责保底
- `RAW` 负责在 x86 host 上保留更高上限

## 风险

主要风险包括：

- TB hash 入口状态增加后，TB 数量可能增多
- `RAW/SPLIT` 在热点间频繁切换，可能导致局部 TB 碎裂
- `CCMP/CCMN` 与 flags transform 的边界如果定得太激进，会重新引入复杂状态机
- 如果 runtime `UNKNOWN` 分流残留过多，方案会被自身开销抵消

## 设计结论

下一步不应继续以 `pending_cc` 为核心扩大旁路命中面。

更合理的方向是：

- 保留 `LIVE_HOST` 作为同 TB 最热瞬时优化
- 把 `DEFERRED_RAW = raw_flags + cc_op` 提升为 durable 主表示之一
- 把 clean 原生风格 `DEFERRED_SPLIT = CF/VF/NF/ZF proxy` 提升为另一 durable 主表示
- 用 `flags_rep` 驱动 TB 级 specialization
- 仅在架构明确要求时才 canonicalize

这条路的第一目标不是继续抬高峰值，而是先把 miss-case 拉回接近原生的下限。

峰值优化应在主表示模型稳定后，再在 `RAW` 路径上继续叠加。

## 实现建议顺序

实现顺序不在本 spec 中展开为逐步 plan，但高层顺序固定为：

1. 先把 `RAW/SPLIT` 作为主表示建模清楚
2. 先把 TB 入口 specialization 跑通
3. 先覆盖最值钱的 `B.cond / CSEL* / ADC/SBC` consumer
4. 先验证 miss-case 是否接近原生
5. 最后再扩 `ADCS/SBCS`、`CCMP/CCMN` 和更复杂 raw consumer

这份设计确认后，再进入单独实现计划。
