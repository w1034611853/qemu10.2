---
id: kb-decision-retain-carry-fallbacks
title: 为什么 CMN 到 ADCS 与 CMP 到 SBCS 仍然保留 fallback
note_type: decision
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: Rationale for keeping CMN->ADCS and CMP->SBCS on fallback paths
summary: >
  解释这两个长期未放开的路径不是“漏做”，而是当前语义模型下的主动保守边界。
tags:
  - decision
  - fallback
  - carry
related_notes:
  - "[[ADCS-SBCS Direct-Consumer 优化线]]"
  - "[[AArch64 NZCV 与宿主 x86 flags 的关系]]"
related_commits:
  - 3150e645b6
source_docs:
  - /home/wangruoyu/qemu10.2/progress.md
  - /home/wangruoyu/qemu10.2/docs/superpowers/specs/2026-04-01-adcs-sbcs-producer-direct-consumer-design.md
external_sources: []
verification_status: partially-verified
verification_refs:
  - "[[当前已完成能力矩阵]]"
confidence: high
next_actions:
  - 若未来引入新 carry representation，再重新评估此决策
decision_date: 2026-04-01
problem_statement: compare-like carry or borrow is not the same as a stable materialized carry producer for ADCS/SBCS consumers.
chosen_option: keep CMN->ADCS and CMP->SBCS on fallback
rejected_options:
  - treat compare-like carry as live materialized carry
decision_drivers:
  - correctness
  - semantic clarity
---

# 为什么 CMN 到 ADCS 与 CMP 到 SBCS 仍然保留 fallback

## 问题是什么

表面上看，`CMN` / `CMP` 也在产生 carry/borrow 相关语义，似乎可以直接继续喂给 `ADCS/SBCS`。但当前项目没有这么做。

## 核心原因

因为 compare-like producer 的 carry/borrow，在当前模型中并不被视作：

- 一个稳定 materialized 的 live host `CF`

换句话说，它的语义来源和当前 direct `ADCS/SBCS` 线依赖的 producer 类型并不相同。

## 为什么这是主动边界，不是待修 bug

如果把这两条路径强行放开，会等于默认接受一个当前并未真正证明的语义桥接关系。这会模糊：

- compare-like pending
- materialized carry producer

之间的边界。

## 当前应如何解读

这两条 fallback 是当前模型的“保守成功”，而不是“还没来得及做完”。
