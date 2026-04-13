---
id: kb-decision-csel-no-peek-keep
title: 为什么 compare-like CSEL 不能继续 peek+keep alive
note_type: decision
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: Rationale for abandoning the old compare-like CSEL peek-and-keep model
summary: >
  记录 compare-like `CSEL/CS*` 为什么不再允许沿用旧的 `peek + keep alive` 生命周期模型。
tags:
  - decision
  - csel
  - lifecycle
related_notes:
  - "[[Compare-like CSEL-CS 重构]]"
  - "[[pending_cc 与 producer-consumer 生命周期]]"
related_commits:
  - 8ecfda40d0
  - 47d27a1bb1
source_docs:
  - /home/wangruoyu/qemu10.2/docs/superpowers/specs/2026-04-02-compare-like-csel-cs-rework-design.md
  - /home/wangruoyu/qemu10.2/progress.md
external_sources: []
verification_status: verified
verification_refs:
  - "[[功能正确性总览]]"
confidence: high
next_actions: []
decision_date: 2026-04-02
problem_statement: compare-like CSEL consumer wants direct condition reuse, but the old keep-alive model broke flags lifetime correctness.
chosen_option: consume condition, then retire producer into split flags
rejected_options:
  - keep using peek plus keep alive with local patches
  - permanently fallback compare-like CSEL/CS*
decision_drivers:
  - correctness
  - lifecycle clarity
  - workload closure
---

# 为什么 compare-like CSEL 不能继续 peek+keep alive

## 问题是什么

旧模型允许 compare-like `CSEL/CS*`：

- 从 `pending_cc` 读取条件
- 然后继续让原 pending compare 活着

问题在于，这让 `CSEL/CS*` 成了一个既透明又不真正结算 flags 生命周期的 consumer。

## 触发背景

`531.deepsjeng_r test` 证明：

- 仅靠 focused harness 过关，不足以说明这个生命周期模型稳
- operand snapshot 一类的局部修补并不能解决根问题

## 为什么不继续修补旧模型

因为根问题不是局部 alias，而是：

- consumer 之后 flags 应该如何被后续看到

只要这个问题没被重新定义清楚，继续在旧模型上打补丁，只会把风险推迟到下一次 workload 暴露。

## 为什么选“消费后退休到 split flags”

因为它保住了 direct condition 的收益，同时把后续 flags 可见性重新放回稳定轨道。

## 代价

代价是失去旧模型设想的长寿命多 consumer 复用收益，但这是为了换 correctness。
