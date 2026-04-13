---
id: kb-template-frontmatter
title: frontmatter 模板
note_type: index
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: Frontmatter templates for core knowledge-base note types
summary: >
  提供 topic、evidence、decision 三类核心笔记的 frontmatter 模板，确保后续新增笔记的字段一致。
tags:
  - template
  - frontmatter
related_notes:
  - "[[命名与状态规范]]"
  - "[[维护规范]]"
related_commits:
  - 104ede8bab
source_docs:
  - /home/wangruoyu/qemu10.2/docs/superpowers/specs/2026-04-08-obsidian-knowledge-base-design.md
external_sources: []
verification_status: design-only
verification_refs: []
confidence: high
next_actions: []
---

# frontmatter 模板

## 通用模板

```yaml
---
id: kb-unique-id
title: 笔记标题
note_type: overview
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: 描述这篇笔记覆盖的范围
summary: >
  1 到 2 句摘要。
tags:
  - nzcv
related_notes: []
related_commits: []
source_docs: []
external_sources: []
verification_status: partially-verified
verification_refs: []
confidence: high
next_actions: []
---
```

## `topic` 模板

```yaml
note_type: topic
current_state: active
completed_scope:
  - 示例范围
known_limits:
  - 示例限制
open_questions:
  - 示例未决问题
```

## `decision` 模板

```yaml
note_type: decision
decision_date: 2026-04-02
problem_statement: 一句话定义问题
chosen_option: 方案 2
rejected_options:
  - 方案 1
  - 方案 3
decision_drivers:
  - correctness
  - lifecycle clarity
```

## `evidence` 模板

```yaml
note_type: evidence
test_date: 2026-04-03
environment: WSL2 Ubuntu 24.04, Ryzen 7 9800X3D
benchmark_scope: SPEC CPU2017 test/train and focused TCG checks
result_kind: functional-and-performance
raw_artifacts:
  - /abs/path/to/artifact.md
```

## 使用提醒

- `as_of` 表示结论时点，不是文件创建时间
- `verification_status` 不要一律写成 `verified`
- `source_docs` 和 `external_sources` 只写真正支撑这篇笔记的来源
