---
id: kb-topic-adcs-sbcs-direct-consumer
title: ADCS-SBCS Direct-Consumer 优化线
note_type: topic
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: ADCS/SBCS direct-consumer line and its current deliberate boundaries
summary: >
  总结 ADCS/SBCS direct-consumer 系列当前已经完成的能力、刻意保留的 fallback，以及它在整个项目中的地位。
tags:
  - topic
  - adcs
  - sbcs
  - direct-consumer
related_notes:
  - "[[当前已完成能力矩阵]]"
  - "[[TCG direct-path 与 lazy compare 基本模型]]"
  - "[[功能正确性总览]]"
related_commits:
  - 3150e645b6
  - 6031cdf33d
source_docs:
  - /home/wangruoyu/qemu10.2/progress.md
  - /home/wangruoyu/qemu10.2/docs/superpowers/specs/2026-04-01-adcs-sbcs-producer-direct-consumer-design.md
external_sources: []
verification_status: verified
verification_refs:
  - "[[TCG focused checks 总览]]"
  - "[[功能正确性总览]]"
confidence: high
next_actions:
  - 持续观察其与更深非分支 chaining 的组合边界
---

# ADCS-SBCS Direct-Consumer 优化线

## 一句话结论

这是目前已经站稳的一条主线：`ADCS/SBCS` 不再只是终点指令，而可以作为一系列后续 direct consumer 的上游 producer；其 correctness 证据相对扎实，且边界定义清楚。

## 当前已完成范围

根据 `progress.md` 当前摘要，已完成的 direct paths 包括：

- `CMN / ADDS xzr -> ADC`
- `CMP / SUBS xzr -> SBC`
- `ADDS rd -> ADC`
- `SUBS rd -> SBC`
- `ADDS rd -> ADCS`
- `SUBS rd -> SBCS`
- `ADCS/SBCS -> ADC/SBC`
- `ADCS/SBCS -> ADCS/SBCS`

## 刻意保留的 fallback

- `CMN -> ADCS`
- `CMP -> SBCS`

这不是“忘了做”，而是当前模型下故意不放开。原因是 compare-like producer 的 carry/borrow 不被视作稳定的 materialized live host `CF`。

## 这条线为什么重要

它证明了两件事：

- direct-consumer 不只适用于最基础的 compare + branch
- setflags / carry-producing family 可以被纳入更广的 direct-path 体系

从项目演进角度看，它是后面 materialized producer 进入非分支 consumer 的前置基础。

## 当前阅读它的正确方式

不要把它理解成“所有带 carry 的路径都已经统一处理完了”，更准确的说法是：

- 一条稳定的 direct-consumer 主线已经成立
- 但 compare-like carry 语义与 materialized carry 语义仍然被谨慎区分

## 验证证据

已知 focused evidence 包括：

- `check-adc-sbc-host-direct.sh`
- `adcsbc-bench`
- `nzcv-status4`
- 以及更宽的 smoke / workload closure

更完整的验证入口见 [[TCG focused checks 总览]] 和 [[功能正确性总览]]。
