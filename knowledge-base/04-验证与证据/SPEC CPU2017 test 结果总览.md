---
id: kb-evidence-spec-test-results
title: SPEC CPU2017 test 结果总览
note_type: evidence
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: Human-readable summary of SPEC CPU2017 test-size correctness evidence
summary: >
  汇总当前知识库中与 SPEC CPU2017 `test` 规模相关的功能正确性结论，并显式区分正常通过项与 `500.perlbench_r` 的已知例外。
tags:
  - evidence
  - spec
related_notes:
  - "[[功能正确性总览]]"
  - "[[已知例外：500.perlbench_r workaround]]"
  - "[[外部功能正确性结果导入]]"
related_commits:
  - 155d294998
  - 6d40860fef
source_docs:
  - /home/wangruoyu/qemu10.2/progress.md
  - /home/wangruoyu/qemu10.2/docs/superpowers/summaries/2026-04-02-spec-cpu2017-seven-test-size-runbook.md
external_sources:
  - /home/wangruoyu/qemu_nzcv/functional_test_results.md
verification_status: verified
verification_refs:
  - "[[外部功能正确性结果导入]]"
confidence: high
next_actions:
  - 后续若引入新的 SPEC test-size 结果，继续并入本页
test_date: 2026-04-03
environment: SPEC CPU2017 test-size runs under qemu-aarch64
benchmark_scope: SPEC intrate test-size correctness
result_kind: benchmark-correctness
raw_artifacts:
  - /home/wangruoyu/qemu10.2/docs/superpowers/summaries/2026-04-02-spec-cpu2017-seven-test-size-runbook.md
  - /home/wangruoyu/qemu_nzcv/functional_test_results.md
---

# SPEC CPU2017 test 结果总览

## 一句话结论

当前知识库中可作为“正常 correctness 通过”的 SPEC `test` workload 主要包括：

- `502.gcc_r`
- `505.mcf_r`
- `520.omnetpp_r`
- `523.xalancbmk_r`
- `525.x264_r`
- `531.deepsjeng_r`
- `541.leela_r`
- `557.xz_r`

`500.perlbench_r` 需要单独按已知例外解读。

## 为什么 SPEC `test` 重要

相对于 focused checker，它更接近真实程序运行语义，尤其擅长暴露：

- 生命周期模型的隐藏漏洞
- 复杂控制流下的错误
- 仅在真实 workload 中出现的路径组合

## 当前可用结论

- `531.deepsjeng_r` 是当前最有代表性的闭环 workload 之一，因为它曾经直接逼出了 compare-like `CSEL/CS*` 的设计切换
- `525.x264_r` 不仅通过，还带有输出质量验证
- 六到八个 benchmark 的通过结果说明“当前主线并非只在微型 harness 下成立”

## `500.perlbench_r` 的特殊性

它的 `test` 规模存在 nested Perl subprocess 可能绕开外层 QEMU wrapper 的问题，因此：

- 单独 miscompare 不足以直接判定 NZCV 优化错误
- 需要结合 wrapper workaround 文档来诊断

## 实际阅读建议

- 把 `502/505/520/523/525/531/541/557` 的通过看作比较干净的 correctness 信号
- 把 `500.perlbench_r` 看作环境和执行模式会污染结论的特殊 benchmark
