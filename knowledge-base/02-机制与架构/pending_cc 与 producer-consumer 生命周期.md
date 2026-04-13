---
id: kb-mechanism-pending-cc-lifecycle
title: pending_cc 与 producer-consumer 生命周期
note_type: mechanism
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: Lifecycle rules for pending producers, consumers, invalidation, and limited rechaining
summary: >
  解释当前 `pending_cc` 如何记录 producer、跨越安全 gap、被 consumer 消费、被立即退休，
  或在极窄场景下被 re-seed 成新的邻接 producer。
tags:
  - mechanism
  - pending-cc
  - lifecycle
related_notes:
  - "[[TCG direct-path 与 lazy compare 基本模型]]"
  - "[[Compare-like CSEL-CS 重构]]"
  - "[[NZCV direct paths 与 producer chaining 当前状态]]"
related_commits:
  - 47d27a1bb1
  - 366b7d6ddb
  - 0c9d65605b
source_docs:
  - /home/wangruoyu/qemu10.2/docs/superpowers/specs/2026-04-01-lazy-compare-phase-2-design.md
  - /home/wangruoyu/qemu10.2/docs/superpowers/specs/2026-04-02-compare-like-csel-cs-rework-design.md
  - /home/wangruoyu/qemu10.2/progress.md
external_sources: []
verification_status: partially-verified
verification_refs:
  - "[[TCG focused checks 总览]]"
confidence: high
next_actions: []
---

# pending_cc 与 producer-consumer 生命周期

## 一句话结论

`pending_cc` 不是“随时都能读的上一条 compare”，而是一份受严格生命周期约束的 pending producer 记录：何时记录、如何跨 gap、何时消费、何时退休、何时允许窄范围 rechain，都必须显式定义。

## 当前生命周期的五个阶段

### 1. record

producer 在符合条件时把必要语义记进 `pending_cc`，例如：

- `lhs / rhs`
- `cc_op`
- kind
- gap 预算

### 2. carry across safe gap

如果后续指令是 whitelist 中的 gap-safe 指令，pending state 可以继续活一小段距离。

### 3. invalidation

一旦遇到下面这类事件，就优先失效：

- flags writer
- 非 whitelist 指令
- gap 超限
- TB / page / control-flow cut

### 4. consume

consumer 命中时，可以按自己的语义读 pending producer。这里的重点是：

- 不同 consumer 不一定共用同一 consume 模型
- terminal consumer 与 transparent consumer 的风险不同

### 5. retire or re-seed

consumer 读完之后，通常要么：

- 退休到稳定 flags 表示
- 要么在极窄的相邻场景下，重建一个新的更局部 producer

这一步正是当前很多设计差异的来源。

## 为什么 `CSEL` 是关键分水岭

`B.cond` 和 `CCMP` 更接近 terminal consumer，而 `CSEL/CS*` 自己不写 flags，却又可能影响后续谁还能看见条件信息。

因此 `CSEL/CS*` 不能简单继承“读完还保持原 pending producer 活着”的模型。

## 当前已经出现的再链式模式

根据最新 `progress.md` 的 current scheme，总体可以看到两类再链：

- flags-transparent `CSEL/CS*` 之后的窄 re-seed
- promoted `CCMP/CCMN` producer 之间的相邻 direct handoff

但这些 rechain 都是：

- 邻接优先
- focused evidence 驱动
- 明确列出“目前还没有覆盖什么”

## 审视代码时最该盯的点

- producer 记录的语义是否足够完整
- consumer 之后是否错误地把旧 pending 生命周期延长
- 某个 host-side convenience codegen 是否会破坏 live flags
- rechain 是真正重新建立了新 producer，还是错误地复用了旧 producer
