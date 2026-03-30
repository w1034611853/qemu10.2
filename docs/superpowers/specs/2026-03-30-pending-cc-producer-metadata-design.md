# pending-cc producer 轻量泛化设计（step 19 之后）

**日期：** 2026-03-30

**状态：** 已确认，可进入实现计划

## 目标

在不新增任何新直通语义的前提下，把当前 `a64_cmp_pending_*` 这组
translation-time metadata 收敛成更中性的 “pending-cc producer” 小结构，
为后续继续扩相邻 producer/consumer 直通做准备。

这一步的目标不是拿新的 perf gain，而是降低后续扩展的重复代码和理解成本：

- 统一记录 compare-like producer 和 materialized producer
- 明确 producer kind，而不是只靠 `materialized + cc_op` 侧推
- 把 record / clear / adjacent-only 判定 / consume 后 canonical state 恢复
  这些公共逻辑收敛成 helper

## 当前问题

当前树里这组 metadata 已经同时承载了 3 类 producer：

1. compare-like producer
   - `CMP / SUBS(xzr) -> B.cond`
   - `CMP / SUBS(xzr) -> plain SBC`
   - `CMN / ADDS(xzr) -> plain ADC`
2. materialized add producer
   - `ADDS rd -> plain ADC`
3. materialized sub producer
   - `SUBS rd -> plain SBC`

但命名和控制流仍然明显停留在最初的 `cmp_pending` 阶段：

- 字段名偏 compare-centric
- materialized producer 只靠 `a64_cmp_pending_materialized` 一位布尔值表达
- consumer helper 里各自重复判断：
  - `pending_valid`
  - `rewind == NULL`
  - `adjacent`
  - `cc_op`
  - `materialized`
- clear/reset 逻辑是字段级手动展开，后续继续扩时很容易漏字段

也就是说，现在功能已经不小了，但承载它的 metadata 模型还太早期。

## 为什么现在做轻量泛化，而不是继续加特例

我们已经明确后续还会继续沿这条线扩：

- 更多 arithmetic producer / consumer 直通
- 更宽的 producer 形式
- 以及更中性的 pending metadata

如果继续沿现状加特例，后面的问题不会是“做不出来”，而是：

- 新增一条直通要再抄一轮条件判断
- 新增一位状态要在多处 reset / trace / consume 逻辑里手填
- code review 时越来越难快速判断哪些 helper 是共享语义、哪些只是历史偶然

而如果现在直接跳到“大一统 framework”，又会过早引入还没被真实需求证明的抽象。

所以这一拍选一个中间态：

- 不引入新行为
- 不追求一口气抽象完整 matrix
- 但把已经被当前实现证明存在的共性先建模出来

## 非目标

这一步不做：

- 新增任何新的 producer / consumer 直通命中
- immediate / ext / gap / cross-TB 扩展
- 改动现有 env gate 语义
- 改动 benchmark 口径
- 改动 backend opcode 设计
- 重命名整个代码库里所有 “cmp” 相关 helper
- 设计完整的通用 arithmetic producer/consumer framework

## 候选方案与取舍

### 方案 1：最窄整理

只做两件事：

- 把 `a64_cmp_pending_materialized` 换成一个更中性的 `kind`
- 抽一个统一 clear/reset helper

优点：

- 风险最低
- 改动面最小

缺点：

- 只能解决最表层的命名问题
- consumer 侧重复判断仍然散在多处
- 很快还会再做第二轮整理

这一步不选它作为最终方案。

### 方案 2：小 struct 泛化

把当前 `a64_cmp_pending_*` 收成一个小结构，例如：

- `A64PendingCCProducer pending_cc;`

再加入一个 producer-kind 枚举，例如：

- `A64_PENDING_CC_REWINDABLE_CMP`
- `A64_PENDING_CC_MATERIALIZED_ADD`
- `A64_PENDING_CC_MATERIALIZED_SUB`

同时抽以下 helper：

- 统一 reset / clear
- 统一 record
- 统一 adjacent-only 判定
- 统一 “consumer 命中后恢复 canonical raw state”

优点：

- 能覆盖当前已经存在的真实共性
- 不需要现在就设计完整 framework
- 后续新增直通时新增点会更集中

缺点：

- 仍然保留一部分历史命名和调用关系
- 不是终局抽象

这一步采用此方案。

### 方案 3：直接做完整 framework

把 producer kind、consumer kind、match rule、env gate、emitter dispatch
全部统一成完整 matrix。

优点：

- 长期最整齐

缺点：

- 会把当前已经稳定的路径一起搅动
- 需要提前决定太多尚未被真实需求验证的抽象维度
- 这一步的收益与风险不匹配

这一步不采用。

## 选定方案

### 总体思路

保留当前行为模型，但把 metadata 从“散落的一组 compare-centric 字段”
收敛成“一个小型 pending-cc producer 结构”。

新的结构只表达当前已经真实存在的维度：

- producer 是否有效
- producer 是哪一类
- 生产的是 32-bit 还是 64-bit flags
- lhs / rhs
- rewind / end
- age / trace 信息
- cc_op
- gap

也就是说，这一步不是做“大而全”的抽象，而是把现状原样建模得更像现状。

## 数据结构设计

### 新结构

建议在 `translate.h` 中引入：

```c
typedef enum A64PendingCCProducerKind {
    A64_PENDING_CC_NONE = 0,
    A64_PENDING_CC_REWINDABLE_CMP,
    A64_PENDING_CC_MATERIALIZED_ADD,
    A64_PENDING_CC_MATERIALIZED_SUB,
} A64PendingCCProducerKind;

typedef struct A64PendingCCProducer {
    bool valid;
    bool keep;
    bool sf;
    TCGv_i64 lhs;
    TCGv_i64 rhs;
    TCGOp *rewind;
    TCGOp *end;
    target_ulong pc;
    uint32_t age;
    bool consumed;
    const char *consumer;
    uint32_t cc_op;
    uint8_t gap_insns;
    A64PendingCCProducerKind kind;
} A64PendingCCProducer;
```

然后在 `DisasContext` 中替换为：

```c
A64PendingCCProducer a64_pending_cc;
```

### 为什么不把 `raw_cc_op` 也并进去

`a64_raw_cc_op` 表示的是当前 TB 对 canonical raw flags 的整体 translation-time
理解，不是某个 pending producer 自身的 metadata。

所以这一步建议：

- 保持 `a64_raw_cc_op` 继续留在 `DisasContext`
- 不把它塞进 `pending_cc`

这样结构边界更清楚。

## 语义映射

### 当前 3 类 producer 的映射方式

#### compare-like producer

当前使用场景：

- `CMP / SUBS(xzr) -> B.cond`
- `CMP / SUBS(xzr) -> plain SBC`
- `CMN / ADDS(xzr) -> plain ADC`

映射：

- `kind = A64_PENDING_CC_REWINDABLE_CMP`
- `rewind != NULL` 时表示支持 rewind / replay
- `cc_op` 继续区分 add-style / sub-style compare producer

#### materialized add producer

当前使用场景：

- `ADDS rd -> plain ADC`

映射：

- `kind = A64_PENDING_CC_MATERIALIZED_ADD`
- `rewind == NULL`
- `cc_op = A64_X86_CC_ADD32/64`

#### materialized sub producer

当前使用场景：

- `SUBS rd -> plain SBC`

映射：

- `kind = A64_PENDING_CC_MATERIALIZED_SUB`
- `rewind == NULL`
- `cc_op = A64_X86_CC_SUB32/64`

### 明确废弃的旧表达

这一步之后不再保留：

- `a64_cmp_pending_materialized`

因为它表达的信息太弱：

- 无法直接区分 add 与 sub
- 读代码的人仍然要回头组合 `materialized + cc_op` 才知道 producer 类型

## helper 设计

### record helper

现有 `a64_record_cmp_for_bcond()` 建议演进为更中性的 helper，例如：

- `a64_record_pending_cc_producer(...)`

它负责：

- 写入 `pending_cc`
- 填好 trace / age / consumed / consumer 初值
- 设置 kind / cc_op / gap / rewind

如果为了减 churn，需要保留旧函数名，也应该让旧函数只做薄包装。

### clear/reset helper

新增统一 helper，例如：

- `a64_clear_pending_cc_producer(DisasContext *s)`

用于：

- context init
- translation 尾部 drop
- overwrite/drop 路径

目标是避免后续新增字段时漏清。

### 通用判定 helper

建议把这些公共判定集中成 helper：

- `a64_pending_cc_is_adjacent_to_curr_insn()`
- `a64_pending_cc_has_live_split_flags()`
- `a64_pending_cc_kind_is_materialized()`
- `a64_pending_cc_matches_cc_op(...)`

这里不要求把所有 consumer 判定完全抽成统一框架，但至少把共享判断收敛。

### canonical state 恢复 helper

当前 `a64_try_emit_x86_cmp_sbc()` 和 `a64_try_emit_x86_add_adc()` 在 consumer
命中后都要做：

- `cpu_x86_cc_op = pending cc_op`
- `a64_note_flags_raw_cc_op(...)`

建议抽成 helper，例如：

- `a64_pending_cc_restore_raw_state_after_consume(...)`

这样后续新增 consumer 时不容易漏这一步。

## 迁移策略

### 第一阶段：纯搬运，不改行为

先引入：

- `A64PendingCCProducerKind`
- `A64PendingCCProducer`
- clear/reset helper

并把 `DisasContext` 上原字段迁移进 struct。

要求：

- 只做字段搬运
- 行为和命中条件不变

### 第二阶段：record / drop / trace 收敛

把：

- record
- overwrite
- consume trace
- drop trace

改成统一读写 `pending_cc`。

### 第三阶段：consumer 共享判断收敛

把 `a64_try_emit_x86_cmp_sbc()` 与 `a64_try_emit_x86_add_adc()` 中的
公共判定和 consume 后状态恢复收敛成 helper。

注意：

- 这一步仍然不要求把两个 helper 合并成一个“大 dispatch”
- 只收敛共享语义，保留各自的 emit 细节

## 风险

### 风险 1：结构整理引入行为回退

这是本步最大的真实风险。

因为这一步目标不是扩功能，而是整理结构，所以任何命中率变化或 codegen
回退都算失败。

缓解方式：

- 分阶段迁移
- 每阶段都跑 focused regression
- 保持 env gate 和 benchmark mode 完全不变

这里的“行为回退”不仅包括 correctness，也包括性能形状回退：

- 命中条件变窄
- codegen 退回旧 decode 链
- 因 helper 重排导致原本相同的 hot path 发出不同 TCG / host 形状

### 风险 2：命名改得过头

如果一口气把所有 helper 从 `cmp_pending` 改成全新命名，会放大 churn。

缓解方式：

- 允许保留部分旧函数名作为薄包装
- 先把数据结构和共享逻辑收起来
- 不强求这一拍完成全量 rename

### 风险 3：抽象超过真实需求

如果现在就为 future matrix 设计过多字段，这一步会从“轻量泛化”
变成“过度设计”。

缓解方式：

- 只纳入当前树里已经存在的 producer kind
- 不预留还没有真实调用方的复杂字段

### 风险 4：translation-time 整理引入可测性能负担

虽然这一步理论上应该是性能中性的，但它仍然可能在两处带来真实回退：

- TB 翻译期 helper / struct 访问变多
- 某些共享 helper 改写后，让原本等价的判断顺序或 emit 细节发生变化

因此这一步不能以“只是重构”为理由默认视为安全。

缓解方式：

- 把 performance 视为 hard gate，而不是软参考
- 保持 microbenchmark mode、env gate 和 spot-check 方法完全不变
- 只要出现超出噪音的稳定负回退，就停止收这一步

## 测试与验收

这一步不新增新的 guest case，但必须确保现有 focused regression 全绿：

- `ninja -C build-aarch64-linux-user qemu-aarch64`
- `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ...`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu .../nzcv-status4`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu .../cmpstress-o3`
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`

附加验收标准：

- `cmnadc64/cmnadc32/addsadc64/addsadc32/subsbc64/subsbc32`
  的 codegen 形状不应退回旧 decode 链
- 必须做 same-binary spot-check：
  - `cmnadc64`
  - `cmnadc32`
  - `addsadc64`
  - `addsadc32`
  - `subsbc64`
  - `subsbc32`
- spot-check 方法必须保持和当前记录一致：
  - same tree
  - same binary
  - 仅切对应 env gate
- 预期结果应基本持平；如果出现超出噪音的稳定负回退，则这一步判定失败，不收

### 性能 hard gate

这一步虽然是结构整理，但在执行上按“不能退化的优化基础设施”对待。

因此实现计划必须把下面这条作为硬门槛：

- 不能以“代码更整齐”为理由接受稳定的性能下降

更具体地说：

- 如果 focused correctness 全绿，但 benchmark 出现稳定负回退
- 即使没有 correctness 问题
- 这一步也不能算完成，必须继续修到持平或放弃该重构路径

## 完成定义

当以下条件同时满足时，这一步可认为完成：

- `DisasContext` 中不再散落一组 `a64_cmp_pending_*` 字段
- compare-like / materialized add / materialized sub 三类 producer
  都通过统一结构表达
- clear / reset / drop / consume 后 canonical state 恢复 已有共享 helper
- focused correctness 全绿
- benchmark 无超出噪音的稳定负回退

## 下一步接口价值

这一步完成后，后续继续扩更多直通时，新增点会更集中：

- 新 producer 主要新增一个 `kind`
- 新 consumer 主要复用统一 pending metadata 判定
- 不需要再复制一套 compare-centric 布尔状态

也就是说，这一步本身不直接带来新的 perf 数字，但它会降低下一批优化的
实现和 review 成本。
