---
id: kb-topic-direct-paths-and-chaining
title: NZCV direct paths 与 producer chaining 当前状态
note_type: topic
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: Current scheme for direct paths, transparent consumes, and adjacent producer rechaining
summary: >
  归纳截至 2026-04-08 当前分支里 direct-path、logic line 和 producer chaining 的整体形态，帮助判断哪里已经形成稳定模式，哪里仍然只是 focused-evidence 级别的扩展。
tags:
  - topic
  - chaining
  - current-scheme
related_notes:
  - "[[当前状态总览]]"
  - "[[pending_cc 与 producer-consumer 生命周期]]"
  - "[[Compare-like Non-branch Consumers]]"
related_commits:
  - 366b7d6ddb
  - 0c9d65605b
source_docs:
  - /home/wangruoyu/qemu10.2/progress.md
external_sources: []
verification_status: partially-verified
verification_refs:
  - "[[TCG focused checks 总览]]"
confidence: medium
next_actions:
  - 后续每有一轮 rechain 扩展时更新此页
---

# NZCV direct paths 与 producer chaining 当前状态

## 一句话结论

截至 `2026-04-08`，当前分支已经从“单 producer 到单 consumer”的 direct-path，发展到一个由 compare-like producer、materialized producer、logic producer 和 promoted `CCMP/CCMN` producer 共同组成的混合体系；但它仍然以 adjacent-first、focused-evidence-first 的方式保守推进。

## 当前 scheme 的核心组成

### compare-like producer line

当前已能支持：

- compare-like producer -> `B.cond`
- compare-like producer -> `CSEL/CS*`
- compare-like producer -> `CCMP/CCMN`
- compare-like producer -> `FCSEL`
- compare-like producer -> `FCCMP`

### materialized producer line

当前已形成：

- `ADDS/SUBS rd -> CSEL/CCMP/FCSEL/FCCMP`
- `ADCS/SBCS rd -> CSEL/CCMP/FCSEL/FCCMP`

### logic producer line

当前已有 focused evidence 的相邻 host-direct 路径包括：

- adjacent `ANDS/TST -> B.cond`
- adjacent `ANDS/TST -> CSEL/CS*`
- adjacent `ANDS/TST -> CCMP/CCMN`

### promoted `CCMP/CCMN` producer line

这是当前最新、最值得特别关注的新 producer 方向。根据 `progress.md` 的 current scheme，它已经有 focused evidence 支撑：

- `CCMP/CCMN -> B.cond`
- `CCMP/CCMN -> CSEL/CS* -> B.cond`
- `CCMP/CCMN -> CSEL/CS* -> CSEL/CS* -> B.cond`
- `CCMP/CCMN -> CSEL/CS* -> CCMP/CCMN -> B.cond`
- direct `CCMP/CCMN -> CCMP/CCMN -> B.cond`
- direct `CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> B.cond`
- direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> B.cond`
- direct `CCMP/CCMN -> CCMP/CCMN -> CCMP/CCMN -> CSEL/CS* -> B.cond`

## 当前最重要的阅读边界

### 1. 新 chaining 基本仍是 adjacent-only

无论是在 `CSEL/CS*` 之后重建 producer，还是 direct `CCMP -> CCMP` handoff，目前重点都在相邻组合上，而不是 gap-tolerant 递归扩展。

### 2. focused evidence 明确列出“还没有什么”

这是当前 scheme 的优点之一。项目没有把未证明的组合包装成“已经成立的通用能力”，而是明确写出：

- 哪些 `CCMP -> CCMP -> CSEL -> CSEL`
  之类的组合还没有 focused evidence
- 哪些 direct handoff 仍未做 gap-tolerant rechain

### 3. 新 producer 模型并不意味着回到旧 keep-alive 风格

尤其在 `CSEL/CS*` 相关路径中，当前 rechain 的正确理解是：

- 原 producer 先按当前正确模型退休
- 再在极窄条件下重建一个新的、更局部的 pending producer

这与旧式“让同一个 compare-like pending 一直活着”不是一回事。

## 当前最值得关注的后续方向

根据 `progress.md` 的 next plan，当前继续往前扩时更像是在做：

- direct `CCMP/CCMN` producer line 的进一步递归扩展
- 或在又一轮 perf review 之后，再决定是否继续更深的 direct-`CCMP` 方向

这表明当前项目的重心已经明显从“补单条 consumer”转向“判断 chaining 深度是否值得继续做”。
