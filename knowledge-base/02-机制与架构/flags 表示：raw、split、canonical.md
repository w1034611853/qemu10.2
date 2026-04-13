---
id: kb-mechanism-flag-representations
title: flags 表示：raw、split、canonical
note_type: mechanism
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: The three practical flag representations used by the current optimization line
summary: >
  解释 raw、split、canonical 三种 flags 表示在当前工程里的角色、转换时机和风险边界。
tags:
  - mechanism
  - flags
related_notes:
  - "[[AArch64 NZCV 与宿主 x86 flags 的关系]]"
  - "[[Compare-like CSEL-CS 重构]]"
related_commits:
  - 47d27a1bb1
  - 366b7d6ddb
source_docs:
  - /home/wangruoyu/qemu10.2/progress.md
  - /home/wangruoyu/qemu10.2/docs/superpowers/specs/2026-04-02-compare-like-csel-cs-rework-design.md
external_sources: []
verification_status: partially-verified
verification_refs:
  - "[[功能正确性总览]]"
confidence: medium
next_actions:
  - 后续若引入新的 host-only flags 形态，再补此页
---

# flags 表示：raw、split、canonical

## 为什么需要多种表示

如果只保留一种 flags 形式，当前项目几乎无法同时满足：

- direct-path 的性能目标
- consumer 之后的稳定语义
- 不同 consumer family 的差异化需求

因此这里实际上在用多层表示切换。

## raw

`raw` 更接近 host 或轻量中间状态，适合：

- 临时保留快速路径收益
- 避免过早完整展开 guest NZCV

风险是：

- 生命周期更脆弱
- 更容易被 host 指令或后续路径误伤

## split

`split` 把 `N/Z/C/V` 拆开保留，是一种在“仍然轻于完整 canonical”与“已恢复稳定 guest 语义”之间的折中。

compare-like `CSEL/CS*` 的 rework 核心之一，就是在 consumer 用完条件之后，把 producer 尽快退休到 split flags，而不是继续悬挂在 compare-like pending 上。

## canonical

`canonical` 是最终对 guest 来说明确、标准、可依赖的 NZCV 语义。

在需要稳定语义、跨更多边界或对外暴露时，最终还是要回到这一层。

## 当前读法

对这条线来说，更准确的理解不是“三者谁更先进”，而是：

- `raw` 更像 performance-oriented transient state
- `split` 更像 correctness-oriented stabilized state
- `canonical` 更像 guest-visible final form

## 为什么这页重要

很多 correctness 问题不是“条件算错了”，而是：

- 本应稳定的时候还停在太脆弱的表示上
- 本应退休的时候却继续让 pending 信息活着

从这个角度看，flags 表示的切换时机本身就是设计的一部分。
