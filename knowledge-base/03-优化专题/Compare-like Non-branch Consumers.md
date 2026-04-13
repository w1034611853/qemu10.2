---
id: kb-topic-compare-like-non-branch
title: Compare-like Non-branch Consumers
note_type: topic
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: Compare-like producers flowing into non-branch consumers and the resulting family structure
summary: >
  概述 compare-like producer 进入 `CSEL/CCMP/FCSEL/FCCMP` 等非分支 consumer 的扩展路径，以及它为什么推动项目从 branch-only 走向更系统的生命周期设计。
tags:
  - topic
  - compare-like
  - non-branch
related_notes:
  - "[[Lazy Compare Phase 2 - B.cond]]"
  - "[[Compare-like CSEL-CS 重构]]"
  - "[[NZCV direct paths 与 producer chaining 当前状态]]"
related_commits:
  - 7ec1f2a038
  - c709c5930f
  - 1c8afa5fe9
  - fbfe69876b
source_docs:
  - /home/wangruoyu/qemu10.2/progress.md
external_sources: []
verification_status: partially-verified
verification_refs:
  - "[[TCG focused checks 总览]]"
confidence: high
next_actions:
  - 持续观察 non-branch family 与更深 rechain 的组合边界
---

# Compare-like Non-branch Consumers

## 一句话结论

这是项目从“branch-only fast path”转向“更完整的 producer-consumer 家族”的关键阶段。当前 compare-like producer 已经能进入多个非分支 consumer family，但每个 family 使用的消费模型并不完全一样。

## 已覆盖的 family

根据当前进展，compare-like producer 已经覆盖：

- `CSEL/CSINC/CSINV/CSNEG/CSET/CSETM`
- `CCMP/CCMN`
- `FCSEL`
- `FCCMP`

## 为什么这是一个结构性阶段

这一步的意义不只是“多了几个 consumer”，而是暴露了一个事实：

- 不同 consumer 对 pending producer 生命周期的要求不同

例如：

- `CCMP/CCMN` 更接近 terminal consumer
- `CSEL/FCSEL` 是 transparent consumer，更容易引发生命周期问题

## 当前项目学到的主要规律

### 1. `CSEL` 和 `FCSEL` 更适合 consumer-local 条件读取

它们需要更接近“本地 peek / derive condition”的模式，而不是简单套用 branch 的 consume 逻辑。

### 2. `CCMP` 和 `FCCMP` 更接近共享布尔判断通路

它们与 terminal consumer 的结构更接近，因此 producer-side 记录常常比 consumer-side 重写更关键。

### 3. first logic slice 是 coverage 发现，不是全新 translator 大改

`ANDS/TST -> CSEL/CCMP` 的第一步说明现有 logical raw-flags producer handling 已经能支持一部分语义；后续更大的价值在于更强 path-shape 验证，而不是单纯“开开关”。

## 当前不该误解的地方

- non-branch family 已广，不代表生命周期模型已经无限泛化
- `CSEL` 路径尤其不能按“看起来能继续 keep alive”来想当然扩展
- 当前许多组合仍然依赖 focused evidence，而非全局普适证明
