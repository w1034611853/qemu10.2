---
id: kb-mechanism-nzcv-vs-x86-flags
title: AArch64 NZCV 与宿主 x86 flags 的关系
note_type: mechanism
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: Relationship between guest NZCV semantics and host x86 flags in this optimization line
summary: >
  解释为什么 guest NZCV 不能等同于 host x86 flags，以及 direct-path 优化为何既有价值又必须保守。
tags:
  - mechanism
  - nzcv
  - x86
related_notes:
  - "[[TCG direct-path 与 lazy compare 基本模型]]"
  - "[[flags 表示：raw、split、canonical]]"
  - "[[ADCS-SBCS Direct-Consumer 优化线]]"
related_commits:
  - 6031cdf33d
  - 366b7d6ddb
source_docs:
  - /home/wangruoyu/qemu10.2/progress.md
  - /home/wangruoyu/qemu10.2/docs/superpowers/specs/2026-04-01-lazy-compare-phase-2-design.md
external_sources: []
verification_status: partially-verified
verification_refs:
  - "[[TCG focused checks 总览]]"
confidence: high
next_actions: []
---

# AArch64 NZCV 与宿主 x86 flags 的关系

## 一句话结论

这条优化线成立的前提不是“guest NZCV 等于 host x86 flags”，而是“在某些严格限定的 producer-consumer 关系下，可以安全地借用 host flags 或其轻量衍生状态，避免过早完整物化 guest NZCV”。

## 为什么不能简单等同

原因至少有三层：

- guest 和 host 的条件码语义并不总是一一对应
- 某些 guest 条件依赖的是特定 producer 的语义，而不是通用的“最近一次比较”
- host flags 很容易被后续 host 指令意外破坏

因此，“能直接利用 host flags”的前提必须非常明确。

## 为什么仍然值得利用

如果每个 producer 都立刻把 guest NZCV 完整展开为稳定表示，会带来额外开销。对于某些典型 shape：

- `compare-like producer -> immediate consumer`
- bounded-gap `producer -> consumer`
- 某些透明 consumer 之后的紧邻再消费

可以利用更轻的状态过渡，减少不必要的物化成本。

## 当前项目的实际做法

这条线并没有试图把所有 guest flags 都变成“长期 live host flags”，而是采取了分层策略：

- 能直接消费时，优先 direct-path
- 不能安全 direct 时，退到 `raw` / `split` / `canonical` 的稳定表示
- 遇到生命周期边界不清楚的情况，优先 invalidation 或 fallback

## 关键后果

### 1. 不是所有 carry/borrow 都能复用

例如当前仍刻意保留：

- `CMN -> ADCS`
- `CMP -> SBCS`

因为 compare-like producer 的 carry/borrow 并没有被视作稳定的 materialized live host `CF`。

### 2. consumer 之后是否还能继续借用，是更难的问题

这正是 compare-like `CSEL/CS*` 那次 rework 的核心教训：条件可以 direct 计算，但 consumer 之后 flags 是否继续悬挂在 pending 状态上，是另一回事。

### 3. logic producer 是另一类约束

像 `ANDS/TST` 这样的路径中，host flags 可以服务相邻 consumer，但一旦后续 host codegen 用了会改 flags 的指令，direct-path 就会被无意破坏。

## 该如何阅读这条线

对人来说，更准确的理解方式是：

- 这是“受控借用 host flags 的工程”
- 不是“让 host flags 直接代替 guest NZCV 的工程”
