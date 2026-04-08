# Obsidian Knowledge Base Design

**日期：** 2026-04-08

**状态：** 已确认，可进入实现计划

## 目标

在当前仓库内建立一个面向人的 Obsidian 知识库，用于整理 AArch64 guest on x86 host
TCG NZCV direct-path / lazy-compare 优化线到目前为止的：

- 背景与目标
- 代码与方案演进
- 关键机制与生命周期模型
- 功能正确性与性能证据
- 路径选择、风险、边界与后续规划

这个知识库不是对 `progress.md` 的简单复制，而是把当前分散在：

- `progress.md`
- `docs/superpowers/specs/`
- `docs/superpowers/plans/`
- `docs/superpowers/summaries/`
- `docs/superpowers/archive/`
- 仓库根目录下的性能 / follow-up 文档
- 仓库外部结果文档

中的信息，重写为一套适合人类阅读、审视和规划的文档库。

## 背景与职责分离

当前仓库中已经存在一套对 AI / agent 很有用的运行态文档体系，其中
`progress.md` 是主入口。它的核心价值在于：

- 记录当前分支 / worktree / 进展状态
- 给后续 AI 直接接手工作提供最新上下文
- 保留最近一轮修改、验证命令和可继续推进的方向

但 `progress.md` 并不适合直接承担面向人的长期知识沉淀。原因包括：

- 运行态信息与长期结论混在一起
- 原始 spec / plan / summary / archive 分散，阅读门槛高
- 不同文档的时间快照不完全一致
- 对“为什么这么设计”和“后续该怎么演进”的解释不够集中

因此需要引入一套新的职责分离：

### `progress.md`

保留为 **面向 AI / agent 的运行态 handoff 文档**，强调：

- 当前可执行状态
- 最近代码与验证进展
- 工作线和注意事项
- 便于下一轮自动化继续工作

### `knowledge-base/`

作为 **面向人的知识库**，强调：

- 为什么这样演进
- 方案与路径如何选择
- 代码结构应如何审视
- 现有边界、风险与下一阶段路线

## 用户与使用场景

知识库需要同时服务两类读者：

### 1. 自己后续继续开发

需求包括：

- 快速恢复上下文
- 判断下一步优先级
- 查某条优化线的边界和约束
- 判断某个新方案是否与现有模型冲突

### 2. 其他人接手或评审

需求包括：

- 在较短时间内理解项目目标和当前状态
- 理解各条优化线之间的关系
- 理解某次设计切换背后的 correctness / performance 原因
- 基于已有材料继续规划或审视代码

## 约束

这次知识库设计的显式约束如下：

- 知识库必须建在当前仓库内，并随代码一起版本管理
- 主要语言使用中文
- 代码符号、commit id、指令名、文件路径保留英文原名
- 知识库面向人，而不是替代 `progress.md`
- 需要吸收仓库外但与当前进展直接相关的关键结果
- 风格采用强结构化、尽可能详细的 Obsidian 笔记模型
- 原始材料尽量保留原位，不打乱已有文档历史

## 非目标

这次设计明确不做：

- 用 Obsidian 替代 `progress.md`
- 把整个 repo 根目录直接当作 vault
- 一次性重写所有历史文档
- 修改 QEMU 官方原生 `docs/` 体系的结构
- 把所有外部原始结果全文复制进仓库
- 把知识库设计成纯时间线归档系统

## 候选组织方案

### 方案 1：按时间线组织

优点：

- 容易复盘“发生了什么”

缺点：

- 不利于按主题理解当前模型
- 不利于后续做方案选择和代码审视
- 长期会退化为流水账档案

不采用。

### 方案 2：按主题组织 + 证据层 + 时间线补充

核心思路：

- 以机制、专题、验证、决策为主视角
- 用时间线补足阶段演进
- 用来源映射保持可追溯

优点：

- 最适合“自己续做 + 他人接手”
- 最适合强结构化 frontmatter
- 既能做知识沉淀，也能做规划和评审

缺点：

- 初次整理成本更高

采用此方案。

### 方案 3：现有文档镜像 + 少量索引

优点：

- 落地最快

缺点：

- 不能解决信息分散和结论不稳定的问题
- 仍然要求读者自己拼接上下文

不采用。

## 选定目录结构

知识库单独建在：

- `knowledge-base/`

而不是把仓库根目录直接作为 Obsidian vault。原因是：

- 仓库根目录包含大量源码、构建产物、官方文档和无关噪音
- 单独 vault 更利于阅读、索引和长期维护
- 可以清晰区分“知识库”和“原始项目文件”

第一层目录如下：

### `knowledge-base/00-首页`

放：

- 知识库首页
- 阅读路线
- 维护规范
- 总术语表

### `knowledge-base/01-项目总览`

放：

- 项目背景与目标
- 当前状态总览
- 当前已完成能力矩阵
- 当前风险、边界与未决问题

### `knowledge-base/02-机制与架构`

放：

- AArch64 NZCV 与宿主 x86 flags 的关系
- TCG direct-path 与 lazy compare 基本模型
- pending producer / consumer 生命周期
- raw / split / canonical flags 表示

### `knowledge-base/03-优化专题`

按优化线建专题，例如：

- ADCS/SBCS direct-consumer
- lazy compare phase 2 / B.cond
- compare-like non-branch consumers
- compare-like CSEL/CS* rework
- producer chaining 当前状态

### `knowledge-base/04-验证与证据`

放：

- focused TCG checks
- 功能正确性汇总
- SPEC / CoreMark / Dhrystone 结果
- 性能对比
- profile 分析
- 已知例外和 workaround

### `knowledge-base/05-决策与方案演进`

放：

- 为什么选当前方案
- 哪些替代方案被放弃
- 哪个 correctness hole 触发了设计切换
- 未来路线选择的依据

### `knowledge-base/06-时间线`

放阶段级时间线，而不是流水账。

### `knowledge-base/07-来源映射`

放：

- 知识笔记到原始文档映射
- 知识笔记到关键提交映射
- 结论来源索引

### `knowledge-base/08-外部导入`

放从仓库外部吸收进来的重要结果摘要与必要快照。

### `knowledge-base/90-模板与规范`

放：

- frontmatter 模板
- 命名规范
- 状态字段说明
- 更新流程说明

## 笔记模型

知识库采用固定 `note_type` 分类，避免任意发挥。

建议的笔记类型：

- `index`
- `overview`
- `mechanism`
- `topic`
- `decision`
- `evidence`
- `timeline`
- `source-map`
- `external-import`
- `glossary`

### 核心 frontmatter 字段

`overview / mechanism / topic / decision / evidence / external-import`
这类核心笔记统一要求以下字段：

```yaml
---
id: kb-topic-example
title: 示例标题
note_type: topic
status: active
as_of: 2026-04-08
created: 2026-04-08
updated: 2026-04-08
owner: wangruoyu
audience:
  - self
  - handoff
scope: AArch64 guest on x86 host TCG NZCV optimization
summary: >
  一段简短摘要。
tags:
  - aarch64
  - x86
  - tcg
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

### 关键字段语义

- `as_of`
  - 这篇笔记的结论截至哪一天
- `status`
  - 建议固定为 `draft / active / superseded / archived`
- `source_docs`
  - 仓库内原始材料路径
- `external_sources`
  - 仓库外来源路径或说明
- `related_commits`
  - 关键提交列表
- `verification_status`
  - 建议固定为
    `design-only / historical / partially-verified / verified`
- `confidence`
  - 建议固定为 `low / medium / high`

### 按类型补充字段

#### `topic`

建议补充：

- `current_state`
- `completed_scope`
- `known_limits`
- `open_questions`

#### `decision`

建议补充：

- `decision_date`
- `problem_statement`
- `chosen_option`
- `rejected_options`
- `decision_drivers`

#### `evidence`

建议补充：

- `test_date`
- `environment`
- `benchmark_scope`
- `result_kind`
- `raw_artifacts`

#### `external-import`

建议补充：

- `imported_from`
- `import_reason`
- `local_snapshot`
- `staleness_risk`

## 正文骨架

### `topic` 笔记

正文固定为：

1. 一句话结论
2. 当前状态
3. 已完成范围
4. 明确不支持 / 仍 fallback 的情况
5. 关键提交与方案演进
6. 验证证据
7. 风险与后续工作
8. 来源

### `decision` 笔记

正文固定为：

1. 问题是什么
2. 触发背景
3. 候选方案
4. 为什么选当前方案
5. 代价与放弃内容
6. 结果与后续影响
7. 来源

### `evidence` 笔记

正文固定为：

1. 测试目标
2. 测试对象与版本
3. 环境
4. 方法
5. 结果
6. 结论边界
7. 原始输出位置

## 命名规则

知识库中的核心笔记优先使用稳定主题名，而不是日期前缀。

例如：

- `ADCS-SBCS Direct-Consumer 优化线.md`
- `Lazy Compare Phase 2 - B.cond.md`
- `为什么 Compare-like CSEL 不能继续 Peek+Keep Alive.md`
- `功能正确性总览.md`

只有时间线、外部导入快照、阶段性档案类笔记才优先使用日期前缀。

这样做的原因是：

- 避免知识库退化为档案堆
- 让读者按主题而不是按日期找信息
- 保持长期链接稳定

## 首批落地范围

第一批不追求把全部历史材料都重写完，而是先建立可用骨架。

### 首批核心笔记

#### `00-首页`

- `知识库首页`
- `阅读路线`
- `维护规范`

#### `01-项目总览`

- `项目背景与目标`
- `当前状态总览`
- `当前已完成能力矩阵`
- `当前风险、边界与未决问题`

#### `02-机制与架构`

- `AArch64 NZCV 与宿主 x86 flags 的关系`
- `TCG direct-path 与 lazy compare 基本模型`
- `pending_cc / producer-consumer 生命周期`
- `flags 表示：raw / split / canonical`

#### `03-优化专题`

- `ADCS-SBCS Direct-Consumer 优化线`
- `Lazy Compare Phase 2 - B.cond`
- `Compare-like Non-branch Consumers`
- `Compare-like CSEL-CS 重构`
- `NZCV direct paths 与 producer chaining 当前状态`

#### `04-验证与证据`

- `功能正确性总览`
- `TCG focused checks 总览`
- `SPEC CPU2017 test 结果总览`
- `性能结果总览`
- `Profile 分析与性能分化解释`
- `已知例外：500.perlbench_r workaround`

#### `05-决策与方案演进`

- `为什么 compare-like CSEL 不能继续 peek+keep alive`
- `为什么 CMN->ADCS / CMP->SBCS 仍然保留 fallback`
- `为什么 lazy compare 先选 bounded gap-safe`
- `为什么知识库结论必须按 as_of 管理`

#### `06-时间线`

- `NZCV 优化主时间线`
- `关键回归与修复节点`

#### `07-来源映射`

- `来源总索引`
- `知识笔记到原始文档映射`
- `知识笔记到关键提交映射`

#### `08-外部导入`

- `外部功能正确性结果导入`
- `外部性能结果导入`
- `外部 profile 分析导入`

## 来源迁移策略

知识库不直接重排原始材料，而是分层处理。

### 1. 知识笔记层

面向人类阅读和思考，负责结论、背景、边界、取舍和规划。

### 2. 来源摘要层

对原始 spec / plan / summary / archive / 外部报告做压缩摘要，指出：

- 这份材料主要提供什么信息
- 时效到哪里
- 是否已被后续结论覆盖

### 3. 来源映射层

明确每篇知识笔记依赖哪些：

- 原始文档
- 关键提交
- 外部结果

### 4. 原始材料层

现有文件保持原位，不改名、不迁移、不重写路径。

## 各类来源的处理规则

### `progress.md`

不直接作为知识库正文复制，而是拆解供以下笔记吸收：

- 当前状态总览
- 当前已完成能力矩阵
- 当前风险、边界与未决问题
- TCG focused checks 总览

### `docs/superpowers/specs/*.md`

主要服务于：

- 机制笔记
- 专题笔记
- 决策笔记

### `docs/superpowers/plans/*.md`

主要作为实现轨迹与方案落地方式的来源，不直接改写成知识正文主轴。

### `docs/superpowers/archive/*.md`

主要作为历史背景、时间线和方案切换原因的来源。

### 仓库根目录下的 follow-up / performance 文档

主要进入：

- 验证与证据
- 决策与方案演进
- 时间线

### 仓库外部结果

原则是：

- 先做摘要化导入
- 引用原始路径
- 只在必要时保留局部快照

不默认整篇复制。

## 更新流程

为了防止 `progress.md` 和知识库双份维护失控，后续采用如下规则。

### 高频更新：`progress.md`

适合记录：

- 新提交
- 临时调试
- 最新验证
- 当前 worktree / branch 状态
- 下一步可执行工作

### 中频更新：知识库的现状 / 专题 / 证据

适合在一条工作线阶段收敛后更新：

- 当前状态总览
- 专题笔记
- 验证与证据总结

### 低频更新：知识库的机制 / 决策

只有当这些内容真正变化时才更新：

- 生命周期模型理解
- 架构性取舍
- 路径选择结论

## 实施顺序

建议按以下顺序落地：

1. 创建 `knowledge-base/` 目录骨架
2. 创建首页、模板、维护规范
3. 创建 `当前状态总览`
4. 创建 `NZCV 优化主时间线`
5. 创建首批核心专题笔记
6. 创建验证与证据总览
7. 创建来源映射和外部导入笔记

## 验收标准

当以下条件同时满足时，第一阶段知识库可视为完成：

- 仓库内存在独立的 `knowledge-base/` vault
- 已建立清晰目录结构和模板规范
- 已有至少一套首页 / 总览 / 时间线 / 专题 / 证据的核心骨架
- `progress.md` 与知识库的职责边界已在文档中明确写出
- 至少一条主线专题可以从背景、机制、证据、决策一路追到来源
- 外部关键结果已有摘要化导入入口

## 风险与缓解

### 风险 1：知识库退化为原文档镜像

缓解：

- 强制“知识笔记层”和“来源层”分离
- 核心笔记必须自己写结论，不能只贴链接

### 风险 2：知识库与 `progress.md` 内容冲突

缓解：

- 每篇核心笔记必须写 `as_of`
- 明确知识库记录稳定结论，`progress.md` 记录运行态状态

### 风险 3：外部结果漂移后无法追溯

缓解：

- 对关键外部材料建立导入摘要
- 必要时记录本地快照位置

### 风险 4：维护成本过高

缓解：

- 第一阶段只做高价值骨架
- 不一次性重写全部历史材料
- 将模板和更新流程固定化

## 结论

这次知识库建设应采用：

- **仓库内独立 vault**
- **主题知识库 + 证据层 + 时间线补充**
- **强结构化 frontmatter**
- **面向人的规划 / 审视 / 路线选择**
- **与 `progress.md` 明确分工**

后续实现阶段只需要按本 spec 逐步落地，不需要重新讨论整体结构。
