---
id: kb-mechanism-direct-path-lazy-compare
title: TCG direct-path 与 lazy compare 基本模型
note_type: mechanism
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: Basic model for direct-path and bounded lazy-compare in the current translator work
summary: >
  解释 direct-path 和 lazy compare 在当前工程中的真实含义，以及它们为什么都以保守边界为前提。
tags:
  - mechanism
  - direct-path
  - lazy-compare
related_notes:
  - "[[pending_cc 与 producer-consumer 生命周期]]"
  - "[[Lazy Compare Phase 2 - B.cond]]"
  - "[[Compare-like Non-branch Consumers]]"
related_commits:
  - 6031cdf33d
  - 366b7d6ddb
  - 0c9d65605b
source_docs:
  - /home/wangruoyu/qemu10.2/docs/superpowers/specs/2026-04-01-lazy-compare-phase-2-design.md
  - /home/wangruoyu/qemu10.2/progress.md
external_sources: []
verification_status: partially-verified
verification_refs:
  - "[[TCG focused checks 总览]]"
confidence: high
next_actions: []
---

# TCG direct-path 与 lazy compare 基本模型

## direct-path 是什么

在这个项目里，direct-path 指的是：

- producer 不立刻完整物化 guest NZCV
- consumer 尽可能直接读取更轻量、更接近 producer 的状态
- 只在必要时才退回稳定 flags 表示

它的目标不是“省掉一切状态转换”，而是尽量把转换放到真正需要的时候。

## lazy compare 是什么

当前 lazy compare 更准确的说法是：

- compare-like producer 记录一份有限寿命的 pending 语义
- 后续若在安全范围内遇到 consumer，可以直接消费
- 一旦越界、遇到 flags writer 或非 whitelist 指令，就立即失效

所以它是 **bounded lazy compare**，不是无限寿命 lazy state。

## 当前模型的三个硬约束

### 1. bounded

当前 phase 2 明确绑定到有限 gap，而不是随意跨越。

### 2. whitelist

不是“看起来无害”的指令都允许跨过去，而是只允许明确列入 `gap-safe` 集合的形态。

### 3. invalidation-first

一旦条件不再足够明确，优先失效和回退，而不是赌继续 direct。

## 这套模型为什么有效

它把最难的问题拆开了：

- producer 能不能记录
- gap 能不能跨
- consumer 怎么读
- consumer 读完之后能不能继续传

这样每次扩展只需要放宽一个局部问题，而不是一次性引入全局 flags scheduler。

## 这套模型为什么还不该过度泛化

当前历史已经证明：

- `B.cond` 的 terminal consume 模型不适合直接拿去套 `CSEL`
- compare-like `CSEL/CS*` 的生命周期要比表面看起来复杂
- direct-path 覆盖率的提高并不自动等于性能净收益

因此当前更像：

- 一套可控的局部工程规则
- 而不是一套已经稳定成熟的全局最优解
