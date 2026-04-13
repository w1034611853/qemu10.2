---
id: kb-topic-compare-like-csel-rework
title: Compare-like CSEL-CS 重构
note_type: topic
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: The correctness-first rework of compare-like CSEL/CS* consumers
summary: >
  总结 compare-like `CSEL/CS*` 从旧 `peek + keep alive` 模型切换到“消费条件后退休到 split flags”模型的原因和影响。
tags:
  - topic
  - csel
  - correctness
related_notes:
  - "[[为什么 compare-like CSEL 不能继续 peek+keep alive]]"
  - "[[pending_cc 与 producer-consumer 生命周期]]"
  - "[[当前风险、边界与未决问题]]"
related_commits:
  - 8ecfda40d0
  - 47d27a1bb1
source_docs:
  - /home/wangruoyu/qemu10.2/docs/superpowers/specs/2026-04-02-compare-like-csel-cs-rework-design.md
  - /home/wangruoyu/qemu10.2/progress.md
external_sources: []
verification_status: verified
verification_refs:
  - "[[TCG focused checks 总览]]"
  - "[[功能正确性总览]]"
confidence: high
next_actions:
  - 后续若再引入新的 transparent rechain，优先对照本页边界
---

# Compare-like CSEL-CS 重构

## 一句话结论

这次重构的核心不是“把 `CSEL/CS*` 重新开回来”，而是明确承认旧的 `peek + keep alive` 生命周期模型不稳，并改成“direct condition + stable post-consume flags”。

## 触发背景

旧模型曾尝试：

- `CSEL/CS*` 从 compare-like `pending_cc` 读取条件
- 继续让原 compare-like pending producer 存活

这个模型在 focused 场景下可工作，但被 `531.deepsjeng_r test` 暴露出真实 correctness hole。

## 新模型做了什么

当前模型改为：

1. consumer 仍然直接根据 compare-like producer 计算条件
2. 但 consumer 用完之后，不再继续长期保持原 pending compare
3. 立即把 producer 对应 NZCV 退休到 split flags
4. 后续 flags user 都看到稳定表示

## 为什么这是关键切换

它把两个问题拆开了：

- 条件能不能 direct 计算
- flags 生命周期能不能继续悬挂在旧 pending producer 上

旧模型试图同时优化两件事，结果在真实 workload 中出问题。新模型保住了第一件事，放弃了第二件事的冒险版本。

## 代价

代价也很明确：

- 不再保留旧模型设想的那种长寿命多 consumer 链式收益

但这正是 correctness-first 取舍。

## 后续影响

后续所有 transparent consumer 的扩展都应该先经过这个问题：

- 这次扩展是在安全地构造“新 producer”
- 还是在不安全地延长“旧 producer”的寿命

这也是当前理解 rechain 设计时最重要的分界线之一。
