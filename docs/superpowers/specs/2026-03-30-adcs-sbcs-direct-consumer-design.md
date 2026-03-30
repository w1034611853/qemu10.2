# `ADDS/SUBS/CMN/CMP -> ADCS/SBCS` 直通设计

**日期：** 2026-03-30

**状态：** 草案已确认，可进入实现计划

## 目标

在 plain `ADC/SBC` direct-consumer 已经覆盖 register / immediate / extended
producer 之后，继续把 same-TB adjacent 的 setflags consumer 也接入同一条
host-carry 直通链路：

- `CMN / ADDS xzr,... -> ADCS`
- `CMP / SUBS xzr,... -> SBCS`
- `ADDS rd,... -> ADCS`
- `SUBS rd,... -> SBCS`

这里的 producer 范围只限当前已经支持的 add/sub 家族：

- register-form
- immediate-form
- extended-register form

目标仍然是复用 x86 host 上已经存在的 live `CF`：

- producer 在识别到相邻 `ADCS/SBCS` consumer 时，也要像当前 plain
  `ADC/SBC` 一样先把 pending metadata 记下来，并把 live `CF` 留在当前
  lowering 链上
- consumer 直接发 host `adc/sbb`
- consumer 自己负责产出结果并捕获新的 raw flags

和 plain `ADC/SBC` 不同，这一步在命中 direct path 后，
**不再恢复 producer 的 raw-flags canonical state**，因为架构上最终可见的 flags
应该来自 `ADCS/SBCS` consumer 自身。

## 为什么现在做这一步

当前已经完成的覆盖主要是：

- `CMP/CMN/ADDS/SUBS -> plain ADC/SBC`
- register / immediate / extended producer 都已接入
- `pending_cc` metadata 已经收整

所以当前最自然的下一步，不是继续扩 producer，而是扩 consumer：

- `do_adc_sbc()` 已经同时承载 `ADC/SBC` 与 `ADCS/SBCS`
- plain consumer 已经有相邻 direct path
- setflags consumer 仍然总是先从 canonical state 取 carry，再进入 `gen_adc_CC()`

这意味着当前还有两块配套空白：

- producer 前瞻目前只认 plain `ADC/SBC`，并不会为相邻 `ADCS/SBCS`
  记录 `pending_cc`
- same-TB adjacent producer 之后，`ADCS/SBCS` 仍然没有直接吃 live host `CF`

从语义上看，这一步也比继续做更远的分支类或条件类优化更顺：

- x86 `adc/sbb` 本来就会同时消费 carry 并重新生成 `CF/OF/SF/ZF`
- 与 AArch64 `ADCS/SBCS` 的“使用 carry 并更新 NZCV”形状天然接近

## 当前实现约束

这一步和已经完成的 plain `ADC/SBC` 直通有一个关键差异：

- plain `ADC/SBC` 不更新架构 flags
- 所以命中 direct consumer 后，要把 producer 的 raw flags 恢复回 canonical state

但 `ADCS/SBCS` 不一样：

- consumer 本身就是新的 flags producer
- 架构上最终应保留的是 consumer 的 raw flags

因此这一步不能简单复用：

- `a64_try_emit_x86_add_adc()`
- `a64_try_emit_x86_cmp_sbc()`

因为这两条 helper 的职责里已经包含：

- 消费 pending producer
- 结束后恢复 producer 的 raw-flags state

这正好和 `ADCS/SBCS` 的目标相反。

这一步需要新逻辑的核心点是：

- 跳过 `a64_get_current_carry_flag()`
- 直接依赖 pending producer 留下的 live `CF`
- 发出带 raw-flags capture 的 host `adc/sbb`
- 让 canonical raw state 直接变成 consumer 的 `ADC/SBC` flags 语义

## 非目标

这一步不做：

- 新 producer 家族扩展
- 新的 `pending_cc.kind`
- 把 `ADCS/SBCS` 普遍推广成新的 pending producer
- gap / cross-TB 扩展
- `CCMP/CCMN` 或 `CSEL` 一类条件 consumer
- 新 env gate
- 全量 CPU SPEC 或 benchmark 性能测试执行

最后一点按当前协作边界明确：

- Codex 负责 focused correctness、codegen guard、benchmark 功能输出
- 用户负责完整性能测试与结果判定

唯一保留的例外是当前已经存在的：

- `SBCS xzr,... -> future B.cond`

这条旧路径本来就会把当前 `SBCS` 当成 compare producer；本步不扩它的能力，
只要求保持现有行为与优先级。

## 候选方案与取舍

### 方案 1：只做 compare-like producer -> `ADCS/SBCS`

覆盖：

- `CMN/CMP -> ADCS/SBCS`

优点：

- 命中路径最直接
- 不涉及 materialized producer

缺点：

- `ADDS/SUBS rd -> ADCS/SBCS` 会留下明显空白
- 很快还得再做第二轮补齐

这一步不采用。

### 方案 2：覆盖当前全部已支持 producer，新增 setflags consumer helper

覆盖：

- compare-like producer
- materialized producer

consumer 侧新增专门 helper，负责：

- 相邻性与 `pending_cc.kind` 判定
- 直接使用 live `CF`
- 产出 consumer 结果
- 捕获 consumer raw flags
- 设置对应 `A64_X86_CC_ADCxx / SBCxx` raw-state

优点：

- 和现有 pending producer 骨架最匹配
- 覆盖完整，不再区分 producer form
- 行为边界最清楚：plain consumer 继续走旧 helper，setflags consumer 走新 helper

缺点：

- 需要小心区分“恢复 producer flags”和“保留 consumer flags”这两类后处理
- 需要补新的 host codegen guard，避免误以为 plain/setflags 路径可共用同一 oracle

这一步采用此方案。

### 方案 3：把 plain/setflags consumer 一次性合并成统一 helper

优点：

- 结构上最整齐

缺点：

- plain 与 setflags 的 flags 生命周期不同
- 一次性合并会把“是否恢复 producer raw state”这种关键差异做得过于隐式
- 这一步目标是安全扩覆盖，不是再做一轮 consumer framework 重构

这一步不采用。

## 选定方案

### 总体思路

这一步不是“只改 consumer”，而是“producer 做最小增量扩展，consumer 做主要新增”。

producer 侧复用当前已经稳定的：

- `pending_cc.kind`
- `pending_cc.cc_op`
- `pending_cc.lhs/rhs`
- `pending_cc` 相邻性判定

但必须补一层新的 producer 前瞻：

- add-side producer 不能再只认相邻 plain `ADC`
- sub-side producer 不能再只认相邻 plain `SBC`
- 需要让现有 producer 记录逻辑也能在 next insn 为 `ADCS/SBCS` 时触发

真正新增逻辑主要集中在 `do_adc_sbc()` 的 setflags consumer 分支：

- `ADC/SBC` 继续走当前路径
- `ADCS/SBCS` 新增相邻 direct-consumer 尝试
- 命中后直接结束，不再调用旧的 `a64_get_current_carry_flag() + gen_adc_CC()`

### producer 设计

producer 范围不新增，只复用当前已经能留下 live `CF` 的这几类：

- `A64_PENDING_CC_REWINDABLE_CMP`
- `A64_PENDING_CC_MATERIALIZED_ADD`
- `A64_PENDING_CC_MATERIALIZED_SUB`

也就是说，这一步不会新增新的 producer kind，
但会扩现有 producer 的相邻 consumer 前瞻与 record 触发条件。

producer form 复用现有覆盖：

- register-form
- immediate-form
- extended-register form

其中 immediate-form 仍然继承现有收窄边界：

- `CMN32 / ADDS xzr,#imm -> ADC32` 当前已被收窄
- 这一收窄会自然传导到 `ADCS32` add-side compare-like producer

这一步不试图在 setflags consumer 中绕过这条既有边界。

### producer 前瞻 / record 设计

当前 producer 之所以会留下 `pending_cc`，依赖的是前瞻 helper 只在发现 next insn
是 plain `ADC/SBC` 时才触发记录。

因此这一步必须先补最小增量的 producer 侧扩展：

- add-side producer 前瞻从“相邻 plain `ADC`”扩成“相邻 `ADC` 或 `ADCS`”
- sub-side producer 前瞻从“相邻 plain `SBC`”扩成“相邻 `SBC` 或 `SBCS`”

这层扩展只影响“是否触发已有 `pending_cc` 记录”：

- 记录内容仍然是现有的 `kind + cc_op + lhs/rhs`
- 不新增 `pending_cc` 字段来显式记录 consumer 是 plain 还是 setflags
- consumer 类型由当前翻译到的 `do_adc_sbc()` 分支自己决定

实现上可以是：

- 扩现有 `a64_find_adjacent_plain_adc()` / `a64_find_adjacent_plain_sbc_*()`
  为更中性的 add/sub-consumer 前瞻
- 或新增并列 helper，再在 producer 里分别判断

这份 spec 不绑定具体 helper 命名，但要求 producer record 必须先能覆盖到
相邻 `ADCS/SBCS`，否则 consumer 新 helper 将拿不到可消费的 `pending_cc`。

## consumer 设计

### 1. add-side：`... -> ADCS`

命中条件：

- `setflags = true`
- `is_sub = false`
- 当前 `pending_cc.cc_op` 为 `ADD32/ADD64`
- producer 与当前 `ADCS` 真正相邻
- 对应 producer family 没有被现有 env gate 禁用

命中后：

- 不调用 `a64_get_current_carry_flag()`
- 不再通过 canonical carry decode 重新取 carry
- 直接发 host `adc`
- 捕获 raw flags
- 结果写入 `rd`
- raw state 记为 `A64_X86_CC_ADC32/ADC64`

关键区别：

- 这里捕获的是 consumer 的 raw flags
- 结束后不调用“恢复 producer raw state”的后处理

### 2. sub-side：`... -> SBCS`

命中条件：

- `setflags = true`
- `is_sub = true`
- 当前 `pending_cc.cc_op` 为 `SUB32/SUB64`
- producer 与当前 `SBCS` 真正相邻
- 对应 producer family 没有被现有 env gate 禁用

命中后：

- 直接使用 producer 留下的 carry/borrow 相关 host flag
- 发 host `sbb`
- 捕获 consumer raw flags
- 结果写入 `rd`
- raw state 记为 `A64_X86_CC_SBC32/SBC64`

和 add-side 一样：

- 不再恢复 producer raw flags
- canonical raw state 的最终拥有者是 `SBCS` consumer

### 3. helper 组织方式

不改现有 plain helper 语义：

- `a64_try_emit_x86_add_adc()`
- `a64_try_emit_x86_cmp_sbc()`

而是新增 setflags consumer helper，职责单一：

- `a64_try_emit_x86_add_adcs()`
- `a64_try_emit_x86_cmp_sbcs()`

如果实现过程中发现 add/sub 侧大部分代码完全对称，可以在此基础上再局部抽共用
helper，但不把 plain/setflags 两套混成一个“大而全”入口。

## `do_adc_sbc()` 侧的控制流

建议顺序是：

1. 先处理 plain consumer 现有 fast path
2. 若 `setflags && is_sub && rd == 31` 且命中现有 `lazy_bcond_cmp`，
   保留旧的 `SBCS xzr -> future B.cond` 路径，不尝试新的 setflags direct path
3. 再处理 setflags consumer 的新 direct path
4. 若都未命中，再回落到旧路径：
   - `a64_get_current_carry_flag()`
   - `gen_adc_CC()` / `gen_adc()` / `gen_sbc()`

这样能保证：

- 当前已经验证过的 plain `ADC/SBC` 行为不被搅动
- 当前已经存在的 `SBCS xzr -> future B.cond` 行为与优先级不被误伤
- setflags 新逻辑只在自己命中时介入

## env gate 策略

这一步不新增 env gate。

仍然沿用当前 producer family 侧的 gate：

- compare-like sub producer：
  - `QEMU_A64_DISABLE_CMP_SBC_DIRECT`
- materialized sub producer：
  - `QEMU_A64_DISABLE_SUB_SBC_DIRECT`
- add-side producer：
  - `QEMU_A64_DISABLE_ADD_ADC_DIRECT`

也就是说：

- `... -> ADCS` 是否允许 direct，继续由 add-side producer gate 决定
- `... -> SBCS` 是否允许 direct，继续由对应 sub-side producer gate 决定

这样能保持“同一 producer family 的 plain/setflags consumer 共用开关语义”，
避免再引入新的调参维度。

## 测试与验证

### focused correctness

这一步仍然要求补齐并运行：

- `ninja -C build-aarch64-linux-user qemu-aarch64`
- host codegen guard
- `nzcv-status4`
- `cmpstress-o3`
- `run-adcsbc-bench`

### host codegen guard

需要新增或扩展：

- `adc-sbc-host-direct.S`
- `check-adc-sbc-host-direct.sh`

覆盖至少包括：

- register-form `CMN/CMP -> ADCS/SBCS`
- materialized `ADDS/SUBS rd -> ADCS/SBCS`
- immediate/ext 至少各有 smoke case，证明 setflags consumer 确实命中 direct path
- `SBCS xzr -> future B.cond` 保优先级的 regression case

guard 的关注点应从“有 `adc/sbb`”进一步收紧到：

- consumer 前面没有多余的 canonical carry decode 胶水
- 末尾确实保留 consumer raw-flags capture

### 语义覆盖

`nzcv-status4.S` 需要补：

- `ADCS` 命中 direct path 后的 `NZCV`
- `SBCS` 命中 direct path 后的 `NZCV`
- compare-like producer 与 materialized producer 各至少一组
- 32-bit/64-bit 都要覆盖

要特别确认：

- 最终 flags 来自 consumer，不是 producer

### benchmark 功能输出

仍然需要补 dedicated benchmark mode 与 golden output，方便后续人工 perf：

- `cmnadcs64/32`
- `addsadcs64/32`
- `cmpsbcs64/32`
- `subsbcs64/32`

这里的要求是：

- Codex 负责让 benchmark 功能输出稳定、hash 正确
- 不在这一步由 Codex 执行 timing A/B 或 CPU SPEC perf 测试

完整性能测试由用户在实现完成后执行。

## 风险

### 风险 1：把 plain/setflags consumer 的 flags 生命周期混掉

这是这一步最大的真实风险。

如果实现时错误复用了 plain helper 的后处理：

- 就可能在 `ADCS/SBCS` 命中 direct path 后
- 把 consumer 刚生成的 raw flags 又覆盖回 producer 的 state

这会直接造成架构语义错误。

### 风险 2：setflags consumer 命中 direct path，但仍残留 canonical carry decode 胶水

如果新 path 表面命中了 direct，实际上前面还保留：

- `a64_get_current_carry_flag()`
- 额外的 carry 物化/搬运

那收益会被明显稀释，甚至出现负回退。

这一步虽然不由 Codex 执行 perf 测试，但 codegen guard 仍要尽量把这类形状问题
提前拦住。

### 风险 3：sub-side borrow 语义处理错误

`SBCS` 与 x86 `sbb` 的 carry/borrow 关系比 add-side 更容易出错。

因此 sub-side 语义覆盖必须更偏重：

- 边界 borrow
- 结果为零
- 溢出相关组合

### 风险 4：producer 前瞻扩了 `ADCS/SBCS`，却误伤现有 plain 或 bcond 路径

因为这一步不是纯 consumer 改动，producer lookahead 也要跟着扩。

所以要特别防止两类回归：

- plain `ADC/SBC` 现有 direct path 命中条件被改坏
- `SBCS xzr -> future B.cond` 的优先级被新的相邻 consumer 判定抢走

## 回滚与收窄策略

如果实现后发现某条子路径有独立问题，优先按最小范围收窄：

- 先按 add/sub side 收窄
- 再按 32/64-bit 收窄
- 再按 producer form 收窄

不先引入新的 per-subpath env gate。

如果最终发现 setflags consumer 这一步本身没有拿到足够干净的 code shape，
就回退到：

- 保留文档、测试骨架和 benchmark mode
- 关闭对应子路径 direct 命中

而不是勉强把不稳的实现留下来。
