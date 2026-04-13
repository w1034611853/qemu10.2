---
id: kb-timeline-main
title: NZCV 优化主时间线
note_type: timeline
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: Milestone timeline for the NZCV optimization line from late March to April 8, 2026
summary: >
  以里程碑方式串起这条线从 direct-consumer 起步到 lazy compare、non-branch family、
  CSEL rework 和最新 chaining 扩展的主演进轨迹。
tags:
  - timeline
  - milestones
related_notes:
  - "[[当前状态总览]]"
  - "[[关键回归与修复节点]]"
related_commits:
  - 9417f5fde2
  - 3150e645b6
  - 47d27a1bb1
  - 366b7d6ddb
  - 0c9d65605b
source_docs:
  - /home/wangruoyu/qemu10.2/progress.md
external_sources: []
verification_status: historical
verification_refs: []
confidence: high
next_actions:
  - 后续每个阶段合入后补一条里程碑
---

# NZCV 优化主时间线

## 2026-03-28 到 2026-03-30：direct-consumer 基础期

- 邻接 `ADC/SBC` direct consumer 起步
- `pending_cc` producer metadata 被统一
- immediate / extended addsub direct-consumer 方案逐步补齐

## 2026-03-31 到 2026-04-01：ADCS/SBCS 与 lazy compare phase 2

- `ADCS/SBCS` direct-consumer 线收敛
- lazy compare `B.cond` 的 bounded-gap 设计明确化
- gap harness 和 invalidation coverage 加强

## 2026-04-02：non-branch family 快速扩张

- compare-like `CSEL`
- compare-like `CCMP`
- compare-like `FCSEL`
- compare-like `FCCMP`
- materialized `ADDS/SUBS rd`
- materialized `ADCS/SBCS rd`

这一天是项目从 branch-only 走向多 family producer-consumer 体系的关键跳跃。

## 2026-04-02：closure 与 runbook 整理

- SPEC runbook
- `perlbench` workaround
- worktree closure / merge 策略整理

## 2026-04-03 到 2026-04-07：功能验证与性能认识成形

- 功能正确性外部报告形成
- 性能报告形成
- 性能分化与 hit-rate 思路逐渐明确

## 2026-04-02 到 2026-04-07：compare-like CSEL rework

- compare-like `CSEL/CS*` 暂时关闭
- 设计 spec 落地
- `peek + keep alive` 被放弃
- `47d27a1bb1` 以 correctness-first 模型恢复主线

## 2026-04-07 到 2026-04-08：logic 与 chaining 进入新阶段

- logic producer host-direct 路径继续扩展
- `cmp -> csel -> bcond`、`cmp -> csel -> ccmp` 等链式组合有 focused evidence
- promoted `CCMP/CCMN` producer line 出现更深 adjacent direct handoff
- `366b7d6ddb` 与 `0c9d65605b` 把 direct paths 与 producer chaining 推到新的 current scheme
