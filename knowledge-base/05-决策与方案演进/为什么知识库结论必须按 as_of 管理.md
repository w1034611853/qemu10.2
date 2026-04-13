---
id: kb-decision-as-of-discipline
title: 为什么知识库结论必须按 as_of 管理
note_type: decision
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: Rationale for explicit as_of dating in human knowledge notes
summary: >
  解释为什么这个知识库必须把“结论截至何时”结构化写出来，否则会把不同快照的文档错误地混成同一层现状。
tags:
  - decision
  - knowledge-base
  - as-of
related_notes:
  - "[[维护规范]]"
  - "[[当前状态总览]]"
related_commits:
  - 104ede8bab
source_docs:
  - /home/wangruoyu/qemu10.2/docs/superpowers/specs/2026-04-08-obsidian-knowledge-base-design.md
  - /home/wangruoyu/qemu10.2/progress.md
external_sources:
  - /home/wangruoyu/qemu_nzcv/functional_test_results.md
  - /home/wangruoyu/qemu_nzcv/performance_test_results.md
verification_status: design-only
verification_refs: []
confidence: high
next_actions: []
decision_date: 2026-04-08
problem_statement: Repo-local docs, external reports, and recent commits do not all describe exactly the same project state snapshot.
chosen_option: require explicit as_of on core notes
rejected_options:
  - rely only on file modified time
  - assume progress.md always reflects latest human-readable state
decision_drivers:
  - traceability
  - snapshot clarity
---

# 为什么知识库结论必须按 as_of 管理

## 问题是什么

当前材料天然来自不同时间点：

- `progress.md`
- 旧 spec / summary / archive
- 仓库外功能和性能报告
- 最新代码提交

它们并不会天然对齐到同一个项目状态。

## 如果不写 `as_of` 会发生什么

- 读者会把旧结论误读成当前现状
- 新旧验证结果会被错误叠加
- 人类规划时会基于错误快照做判断

## 为什么这对这个项目尤其重要

因为这条线演进很快，而且最近几笔提交已经证明：

- 人类面向的总览叙事
- AI 运行态 handoff
- 外部报告

三者可能在“各自都对”的前提下，仍然描述的是不同截面。

## 结论

`as_of` 不是格式洁癖，而是防止知识库把不同快照混成一锅的必要约束。
