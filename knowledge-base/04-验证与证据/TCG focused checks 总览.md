---
id: kb-evidence-focused-checks
title: TCG focused checks 总览
note_type: evidence
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: Focused TCG checks and path-shape oracles for the current optimization line
summary: >
  整理当前知识库应重点关注的 focused checker 家族，说明它们分别验证哪类 direct-path 或 chaining 形态。
tags:
  - evidence
  - tcg
  - focused-checks
related_notes:
  - "[[功能正确性总览]]"
  - "[[NZCV direct paths 与 producer chaining 当前状态]]"
related_commits:
  - 366b7d6ddb
  - 0c9d65605b
source_docs:
  - /home/wangruoyu/qemu10.2/progress.md
external_sources: []
verification_status: verified
verification_refs:
  - "[[功能正确性总览]]"
confidence: high
next_actions:
  - 后续出现新 checker family 时补充分组
test_date: 2026-04-08
environment: local focused TCG regression and host-direct oracles
benchmark_scope: unit-like path-shape and semantic checks
result_kind: focused-regression
raw_artifacts:
  - /home/wangruoyu/qemu10.2/progress.md
---

# TCG focused checks 总览

## 测试目标

这些 checker 的价值不是“代表所有 workload”，而是：

- 验证某条 direct-path 是否真的被命中
- 验证 path shape 是否符合预期
- 验证特定 producer-consumer 或 chaining 组合的语义是否还对

## 当前主要 checker 家族

### 基础主线

- `nzcv-status4`
- `cmpstress-o3`
- `adcsbc-bench`
- `check-adc-sbc-host-direct.sh`
- `check-cmp-bcond-gap-host-direct.sh`

### Compare-like gap families

- `check-cmp-csel-gap-host-direct.sh`
- `check-cmp-ccmp-gap-host-direct.sh`
- `check-cmp-fcsel-gap-host-direct.sh`
- `check-cmp-fccmp-gap-host-direct.sh`

### Logic families

- `check-logic-csel-host-direct.sh`
- `check-logic-ccmp-host-direct.sh`
- `check-logic-bcond-host-direct.sh`
- `check-logic-csel-ccmp-gap-host-direct.sh`

### Materialized add/sub and carry producer families

- `check-subs-rd-*`
- `check-adds-rd-*`
- `check-adcs-rd-*`
- `check-sbcs-rd-*`

### Chaining families

- `check-cmp-csel-bcond-chain-host-direct.sh`
- `check-cmp-csel-ccmp-chain-host-direct.sh`
- `check-cmp-csel-csel-chain-host-direct.sh`
- `check-cmp-ccmp-*chain-host-direct.sh`

## 如何解读它们

### 优势

- 反馈快
- 能精确定位某条 path 是否被命中
- 很适合在局部扩展时做第一层安全网

### 局限

- 对更长生命周期或复杂 workload 的覆盖有限
- 并不自动证明 wider performance story
- 通过 focused checker 之后，仍可能被 SPEC 类 workload 暴露问题

## 当前知识库中的定位

这些 checker 是“代码级证据层”的主体。读者在判断某条能力是否真的存在时，应该优先看是否已经有相应 focused family，而不是只看提交标题。
