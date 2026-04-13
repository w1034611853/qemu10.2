# Obsidian Knowledge Base Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an in-repo Obsidian knowledge base that reorganizes the current NZCV optimization progress, design rationale, validation evidence, and planning context into human-oriented notes while keeping `progress.md` as the AI-facing running handoff.

**Architecture:** Create a dedicated `knowledge-base/` vault with a stable directory structure, frontmatter conventions, and navigation notes. Fill the first wave of overview, mechanism, topic, evidence, timeline, and source-mapping notes by synthesizing existing repo-local documents and selected external reports into structured, cross-linked Markdown notes.

**Tech Stack:** Markdown, Obsidian-style wiki links, repo-local specs/plans/summaries/archive docs, external Markdown result reports, Git

---

## File Map

| File | Responsibility |
|------|------|
| `knowledge-base/00-首页/知识库首页.md` | Vault landing page with reading entry points |
| `knowledge-base/00-首页/阅读路线.md` | Suggested human reading paths for different use cases |
| `knowledge-base/00-首页/维护规范.md` | Rules for what belongs in the knowledge base vs `progress.md` |
| `knowledge-base/01-项目总览/项目背景与目标.md` | Explain project scope and motivation |
| `knowledge-base/01-项目总览/当前状态总览.md` | Human-readable current state summary |
| `knowledge-base/01-项目总览/当前已完成能力矩阵.md` | Consolidated capability matrix and fallback boundaries |
| `knowledge-base/01-项目总览/当前风险、边界与未决问题.md` | Open risks and planning-oriented boundaries |
| `knowledge-base/02-机制与架构/*.md` | Core mechanism notes for NZCV, pending_cc, and flag models |
| `knowledge-base/03-优化专题/*.md` | Topic-focused notes for each major optimization line |
| `knowledge-base/04-验证与证据/*.md` | Summaries of focused checks, correctness, performance, and profile evidence |
| `knowledge-base/05-决策与方案演进/*.md` | Decision notes explaining major design choices |
| `knowledge-base/06-时间线/*.md` | Milestone timeline and regression/recovery timeline |
| `knowledge-base/07-来源映射/*.md` | Traceability notes from knowledge notes to original docs and commits |
| `knowledge-base/08-外部导入/*.md` | Summarized imports of external validation/performance/profile reports |
| `knowledge-base/90-模板与规范/*.md` | Templates and metadata conventions |

## Task 1: Scaffold the Vault Structure and Conventions

**Files:**
- Create: `knowledge-base/00-首页/知识库首页.md`
- Create: `knowledge-base/00-首页/阅读路线.md`
- Create: `knowledge-base/00-首页/维护规范.md`
- Create: `knowledge-base/90-模板与规范/frontmatter 模板.md`
- Create: `knowledge-base/90-模板与规范/命名与状态规范.md`
- Create: `knowledge-base/90-模板与规范/术语表.md`

- [ ] **Step 1: Create the directory structure**

Create:

```text
knowledge-base/
knowledge-base/00-首页/
knowledge-base/01-项目总览/
knowledge-base/02-机制与架构/
knowledge-base/03-优化专题/
knowledge-base/04-验证与证据/
knowledge-base/05-决策与方案演进/
knowledge-base/06-时间线/
knowledge-base/07-来源映射/
knowledge-base/08-外部导入/
knowledge-base/90-模板与规范/
```

- [ ] **Step 2: Write the vault landing page**

Create `knowledge-base/00-首页/知识库首页.md` with:

- vault purpose
- audience
- key reading entry points
- explicit distinction from `progress.md`

- [ ] **Step 3: Write the reading guide and maintenance rules**

Create:

- `knowledge-base/00-首页/阅读路线.md`
- `knowledge-base/00-首页/维护规范.md`

The maintenance note must explicitly define:

- what stays in `progress.md`
- what should be promoted into the knowledge base
- how `as_of` should be updated

- [ ] **Step 4: Write metadata and naming templates**

Create:

- `knowledge-base/90-模板与规范/frontmatter 模板.md`
- `knowledge-base/90-模板与规范/命名与状态规范.md`
- `knowledge-base/90-模板与规范/术语表.md`

- [ ] **Step 5: Verify the scaffold exists**

Run:

```bash
find knowledge-base -maxdepth 2 -type f | sort
```

Expected:

- all first-wave scaffold files appear

## Task 2: Write Overview Notes for Human Handoff and Planning

**Files:**
- Create: `knowledge-base/01-项目总览/项目背景与目标.md`
- Create: `knowledge-base/01-项目总览/当前状态总览.md`
- Create: `knowledge-base/01-项目总览/当前已完成能力矩阵.md`
- Create: `knowledge-base/01-项目总览/当前风险、边界与未决问题.md`
- Source: `progress.md`
- Source: `docs/superpowers/specs/2026-04-08-obsidian-knowledge-base-design.md`

- [ ] **Step 1: Draft the project background note**

Summarize:

- AArch64 guest on x86 host context
- NZCV optimization goal
- why this line matters

- [ ] **Step 2: Draft the current-state note**

Use `progress.md` as the primary source, but rewrite it for humans:

- current main conclusions
- what is complete
- what is active or recently extended
- where confidence is strong vs partial

- [ ] **Step 3: Draft the capability matrix note**

Consolidate currently supported direct paths, intentional fallbacks, and important scope limits into a structured note.

- [ ] **Step 4: Draft the risk and open-questions note**

Focus on:

- correctness-sensitive edges
- performance tradeoffs
- planning choices still open

- [ ] **Step 5: Verify the overview note set**

Run:

```bash
rg -n "^id:|^title:|^note_type:|^as_of:" knowledge-base/01-项目总览
```

Expected:

- each overview note contains the required metadata fields

## Task 3: Write Mechanism and Topic Notes

**Files:**
- Create: `knowledge-base/02-机制与架构/AArch64 NZCV 与宿主 x86 flags 的关系.md`
- Create: `knowledge-base/02-机制与架构/TCG direct-path 与 lazy compare 基本模型.md`
- Create: `knowledge-base/02-机制与架构/pending_cc 与 producer-consumer 生命周期.md`
- Create: `knowledge-base/02-机制与架构/flags 表示：raw、split、canonical.md`
- Create: `knowledge-base/03-优化专题/ADCS-SBCS Direct-Consumer 优化线.md`
- Create: `knowledge-base/03-优化专题/Lazy Compare Phase 2 - B.cond.md`
- Create: `knowledge-base/03-优化专题/Compare-like Non-branch Consumers.md`
- Create: `knowledge-base/03-优化专题/Compare-like CSEL-CS 重构.md`
- Create: `knowledge-base/03-优化专题/NZCV direct paths 与 producer chaining 当前状态.md`
- Source: `docs/superpowers/specs/*.md`
- Source: `docs/superpowers/archive/*.md`
- Source: `progress.md`

- [ ] **Step 1: Write the mechanism notes**

Translate the model into human-readable notes:

- what state is carried
- how producer and consumer relate
- where direct-path stops and fallback begins

- [ ] **Step 2: Write the direct-consumer topic note**

Cover:

- supported `ADCS/SBCS` direct lines
- intentional exclusions
- current confidence level

- [ ] **Step 3: Write the lazy-compare and non-branch topic notes**

Cover:

- bounded-gap design for `B.cond`
- compare-like non-branch family shape
- current rollout boundaries

- [ ] **Step 4: Write the CSEL rework and producer-chaining notes**

Explain:

- why the old `peek + keep alive` model became unsafe
- what the rework changed
- how current chaining status should be read

- [ ] **Step 5: Verify topic/mechanism link coverage**

Run:

```bash
rg -n "\\[\\[" knowledge-base/02-机制与架构 knowledge-base/03-优化专题
```

Expected:

- each core note contains Obsidian links to related notes

## Task 4: Write Evidence, Decisions, Timeline, and Source Maps

**Files:**
- Create: `knowledge-base/04-验证与证据/功能正确性总览.md`
- Create: `knowledge-base/04-验证与证据/TCG focused checks 总览.md`
- Create: `knowledge-base/04-验证与证据/SPEC CPU2017 test 结果总览.md`
- Create: `knowledge-base/04-验证与证据/性能结果总览.md`
- Create: `knowledge-base/04-验证与证据/Profile 分析与性能分化解释.md`
- Create: `knowledge-base/04-验证与证据/已知例外：500.perlbench_r workaround.md`
- Create: `knowledge-base/05-决策与方案演进/为什么 compare-like CSEL 不能继续 peek+keep alive.md`
- Create: `knowledge-base/05-决策与方案演进/为什么 CMN 到 ADCS 与 CMP 到 SBCS 仍然保留 fallback.md`
- Create: `knowledge-base/05-决策与方案演进/为什么 lazy compare 先选 bounded gap-safe.md`
- Create: `knowledge-base/05-决策与方案演进/为什么知识库结论必须按 as_of 管理.md`
- Create: `knowledge-base/06-时间线/NZCV 优化主时间线.md`
- Create: `knowledge-base/06-时间线/关键回归与修复节点.md`
- Create: `knowledge-base/07-来源映射/来源总索引.md`
- Create: `knowledge-base/07-来源映射/知识笔记到原始文档映射.md`
- Create: `knowledge-base/07-来源映射/知识笔记到关键提交映射.md`
- Create: `knowledge-base/08-外部导入/外部功能正确性结果导入.md`
- Create: `knowledge-base/08-外部导入/外部性能结果导入.md`
- Create: `knowledge-base/08-外部导入/外部 profile 分析导入.md`
- Source: `a64_tcg_cmpjcc_followup_tasks.md`
- Source: `a64_tcg_cmpjcc_perf_results.md`
- Source: `performance_report/2026-04-03-nzcv-optimization-report.md`
- Source: `/home/wangruoyu/qemu_nzcv/functional_test_results.md`
- Source: `/home/wangruoyu/qemu_nzcv/performance_test_results.md`
- Source: `/home/wangruoyu/qemu_nzcv/nzcv_profile_analysis.md`

- [ ] **Step 1: Write the evidence notes**

Summarize:

- focused local checks
- external functional correctness
- external performance measurements
- known caveats and evidence boundaries

- [ ] **Step 2: Write the decision notes**

Capture the rationale behind:

- CSEL rework
- retained fallbacks
- bounded-gap lazy compare
- `as_of` discipline

- [ ] **Step 3: Write the timeline notes**

Build milestone-oriented notes that explain:

- major implementation waves
- regression discovery
- rework and verification closure

- [ ] **Step 4: Write the source maps and external-import notes**

Make traceability explicit between:

- knowledge notes
- repo-local source docs
- key commits
- external reports

- [ ] **Step 5: Verify source traceability coverage**

Run:

```bash
rg -n "^source_docs:|^external_sources:|^related_commits:" knowledge-base
```

Expected:

- all core notes expose source metadata

## Task 5: Perform Final Vault Verification

**Files:**
- Verify: `knowledge-base/`
- Verify: `docs/superpowers/specs/2026-04-08-obsidian-knowledge-base-design.md`

- [ ] **Step 1: Check all knowledge-base files exist**

Run:

```bash
find knowledge-base -type f | sort
```

Expected:

- the first-wave vault files are present

- [ ] **Step 2: Check for missing metadata on core notes**

Run:

```bash
rg -L "^as_of:" knowledge-base/01-项目总览 knowledge-base/02-机制与架构 \
  knowledge-base/03-优化专题 knowledge-base/04-验证与证据 \
  knowledge-base/05-决策与方案演进 knowledge-base/06-时间线 \
  knowledge-base/07-来源映射 knowledge-base/08-外部导入
```

Expected:

- no output

- [ ] **Step 3: Check for malformed patch artifacts or tab damage**

Run:

```bash
git diff --check
```

Expected:

- no output

- [ ] **Step 4: Review the final diff**

Run:

```bash
git diff --stat
```

Expected:

- new `knowledge-base/` files plus any supporting plan/spec updates

- [ ] **Step 5: Summarize the vault**

Prepare a concise summary that explains:

- what the first-wave vault now contains
- what evidence was imported
- what remains for future expansion
