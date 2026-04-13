---
id: kb-evidence-profile-analysis
title: Profile 分析与性能分化解释
note_type: evidence
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: External profile-style explanation for why performance varies across workloads
summary: >
  解释为什么同一条 NZCV 优化线会在 `mcf_r` 上受益、在 `deepsjeng_r` / `leela_r` 上回退，并把这件事转化为后续路线选择依据。
tags:
  - evidence
  - performance
  - profile
related_notes:
  - "[[性能结果总览]]"
  - "[[当前风险、边界与未决问题]]"
  - "[[外部 profile 分析导入]]"
related_commits:
  - 7ac84129e7
source_docs:
  - /home/wangruoyu/qemu10.2/performance_report/2026-04-03-nzcv-optimization-report.md
external_sources:
  - /home/wangruoyu/qemu_nzcv/nzcv_profile_analysis.md
verification_status: historical
verification_refs:
  - "[[外部 profile 分析导入]]"
confidence: medium
next_actions:
  - 若后续有真实运行统计，应以实测覆盖更新此页
test_date: 2026-04-03
environment: external workload analysis
benchmark_scope: mcf_r, deepsjeng_r, leela_r
result_kind: analytical-explanation
raw_artifacts:
  - /home/wangruoyu/qemu_nzcv/nzcv_profile_analysis.md
---

# Profile 分析与性能分化解释

## 一句话结论

当前对性能分化最有解释力的模型是：收益取决于 cmp producer 被下一个直接 branch 或 direct consumer 命中的比例；命中率高时收益显著，命中率低时 recording / overwrite 开销会反噬。

## 当前给出的典型对比

### `mcf_r`

- 图算法、指针追踪多
- compare 后立即 branch 的比例高
- 因此命中率高，收益明显

### `deepsjeng_r` / `leela_r`

- 递归、循环边界、搜索树遍历较多
- 很多 compare 并不会立刻被适合作为 fast path 的 consumer 命中
- 于是 pending state 记录成本较难摊平

## 对路线选择的启发

这意味着后续不该只盯着“再开更多路径”，而要问：

- 这些路径在真实 workload 中命中率如何
- 是否应该按 TB 或 pattern 做 selective disable
- 哪些扩展只会增加 bookkeeping，不会带来实质收益

## 这份分析的可信度边界

它不是来自当前 head 的真实 profile 采样，而更像：

- 结合 workload 结构与现有性能结果做出的解释性分析

因此它非常适合拿来指导“下一步该试什么”，但不应被误读为已经经过全量运行统计确认的最终结论。
