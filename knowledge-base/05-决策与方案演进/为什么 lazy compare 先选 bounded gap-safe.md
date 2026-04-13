---
id: kb-decision-bounded-gap-safe
title: 为什么 lazy compare 先选 bounded gap-safe
note_type: decision
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: Rationale for bounded gap-safe lazy compare instead of aggressive global lifetime expansion
summary: >
  解释为什么当前 lazy compare 采用 bounded-gap whitelist 设计，而不是更激进的全局 lazy flags 调度。
tags:
  - decision
  - lazy-compare
related_notes:
  - "[[Lazy Compare Phase 2 - B.cond]]"
  - "[[TCG direct-path 与 lazy compare 基本模型]]"
related_commits:
  - 491e051771
  - 6031cdf33d
source_docs:
  - /home/wangruoyu/qemu10.2/docs/superpowers/specs/2026-04-01-lazy-compare-phase-2-design.md
  - /home/wangruoyu/qemu10.2/progress.md
external_sources: []
verification_status: partially-verified
verification_refs:
  - "[[TCG focused checks 总览]]"
confidence: high
next_actions:
  - 如果未来想做更激进生命周期扩展，先重写此决策前提
decision_date: 2026-04-01
problem_statement: The project needed to extend compare-like value without opening an unbounded and hard-to-reason global flags scheduler.
chosen_option: bounded gap-safe lazy compare with explicit invalidation
rejected_options:
  - instrumentation only with no semantic rollout
  - global lazy flags everywhere
decision_drivers:
  - correctness
  - rollout control
  - clarity
---

# 为什么 lazy compare 先选 bounded gap-safe

## 问题是什么

项目需要把 compare-like producer 的价值从“只服务 truly-adjacent consumer”扩到更有价值的场景，但又不能一步走成全局生命周期调度器。

## 为什么不直接做更激进方案

更激进的“lazy flags everywhere”虽然潜在收益大，但会同时放大：

- 推理复杂度
- invalidation 风险
- correctness 调试成本

在当前阶段并不划算。

## bounded gap-safe 的优势

- 它把问题控制在有限步长内
- 它让 whitelist 和 invalidation 规则可写清楚
- 它允许按 consumer family 渐进 rollout

## 决策的真正含义

这个选择本质上是在说：

- 当前项目更重视“可控地扩张”
- 而不是“理论上可能更优但难以收束的大一统模型”
