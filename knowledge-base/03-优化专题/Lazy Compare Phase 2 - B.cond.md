---
id: kb-topic-lazy-compare-bcond
title: Lazy Compare Phase 2 - B.cond
note_type: topic
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: Bounded-gap lazy-compare branch line and its current limits
summary: >
  总结 `B.cond` 线从相邻 compare 扩展到 bounded-gap 之后的当前范围、条件覆盖、invalidations、修正历史和后续优先级判断。
tags:
  - topic
  - lazy-compare
  - bcond
related_notes:
  - "[[TCG direct-path 与 lazy compare 基本模型]]"
  - "[[为什么 lazy compare 先选 bounded gap-safe]]"
  - "[[当前风险、边界与未决问题]]"
related_commits:
  - 6031cdf33d
  - 80acb12aae
  - 6653c87c86
source_docs:
  - /home/wangruoyu/qemu10.2/progress.md
  - /home/wangruoyu/qemu10.2/docs/superpowers/specs/2026-04-01-lazy-compare-phase-2-design.md
external_sources: []
verification_status: verified
verification_refs:
  - "[[TCG focused checks 总览]]"
confidence: high
next_actions:
  - 继续观察是否值得进入更细粒度的 selective policy
---

# Lazy Compare Phase 2 - B.cond

## 一句话结论

`B.cond` 已经不是单纯的相邻 compare-branch 直通，而是一条 bounded-gap、带 whitelist 和显式 invalidation 的保守 lazy compare 主线；它已经很广，但当前不再是最优先继续扩张的方向。

## 当前已完成范围

当前 workline 已包含：

- bounded-gap `CMP/SUBS xzr -> B.cond`
- bounded-gap `CMN/ADDS xzr -> B.cond`
- bounded-gap `ADCS xzr -> B.cond`
- bounded-gap `ADCS rd -> B.cond`
- bounded-gap `SBCS rd -> B.cond`

## 当前条件覆盖

根据 `progress.md` 当前摘要，add-side 已覆盖：

- `EQ/NE/CS/CC/HI/LS/GE/LT/GT/LE`
- `MI/PL/VS/VC`

## 当前明确边界

- 非 whitelist gap 指令：不使用
- gap overflow：不使用
- flags writer 出现：不使用
- page boundary / TB cut / direct control-flow cut：producer 可能拒绝记录
- materialized carry-producer adjacency 仍然保守

## 为什么这条线曾经需要修正

`progress.md` 的 closure update 明确记录了一个重要经验：

- add-side lazy `B.cond` 曾经引入 broader smoke/perf crash
- first bad commit 被缩到 `6653c87c86`
- 后续通过 `80acb12aae` 收窄了 unsafe 子集

这说明 `B.cond` 线虽然看起来最直观，但其条件映射并不总能直接从 compare-like 语义平移。

## 为什么它现在不是第一优先级

当前项目判断“不继续先扩 `B.cond`”的原因主要是：

- branch line 已经比较广
- 剩余工作越来越偏局部 coverage / parity / policy
- 下一个更有结构价值的方向是把 bounded pending compare 生命周期复用到非分支 consumer

## 该怎么读这条线

这条线现在更像：

- 一个已经立住的参考模型
- 一个提供 lifecycle / invalidation 经验的基础线

而不是“项目唯一核心”。
