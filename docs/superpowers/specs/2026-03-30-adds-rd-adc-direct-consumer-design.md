# `ADDS rd -> plain ADC` 直连 consumer 设计（1.5 方案）

**日期：** 2026-03-30

**状态：** 已确认，可进入实现计划

## 目标

在现有 x86 host direct-carry 工作基础上，继续把 add-side 直通往前扩一格：

- 让 same-TB、相邻的 `ADDS rd, ...` producer
- 可以把 live host `CF`
- 直接喂给下一条 plain `ADC`

同时还要满足：

- producer 的结果值仍然正确写回 `rd`
- guest 可见的 NZCV 仍然保持为 producer 的 flags
- consumer 前不再从 canonical flags 里 decode carry

这一步只覆盖：

- AArch64 guest on x86 host
- same-TB 相邻 producer / consumer
- register-form `ADDS rd, rn, rm{, shift}`
- plain non-setflags `ADC`

## 为什么采用 `1.5` 方案

我们已经确定，后面大概率还会继续做：

- `ADDS rd -> ADC`
- `SUBS rd -> SBC`
- 更宽的 immediate / ext producer

所以纯粹只按 phase 2 的局部最小 patch 去做，长期会不够；但如果现在就直接重构成完整的“通用 pending-cc producer framework”，又会提前为很多还没被真实需求证明的维度做抽象，风险和 churn 都偏大。

这次选的 `1.5` 方案是：

- 当前实现仍然按最小可交付切片落地
- 但数据流和 metadata 命名刻意往后续通用化靠一点
- 只引入这一步已经被证明需要的状态，不做整套框架重写

## 非目标

这一步不做：

- `SUBS rd -> SBC`
- immediate-form `ADDS`
- extended-form `ADDS`
- 带 gap 的匹配
- cross-TB 匹配
- `ADCS`
- 通用化重命名整个 `a64_cmp_pending` 体系
- 新的“大一统 fused arithmetic producer/consumer backend framework”

## 选定方案

### 总体思路

producer 不再像 phase 1 的 `CMN / ADDS xzr -> ADC` 那样延迟 materialize。

相反，`ADDS rd` 继续复用当前已经存在的 direct producer 路径：

- `gen_add_CC(..., allow_direct = true)`

也就是：

1. 先直接算出 producer 的结果值
2. 直接 capture producer raw flags 到 canonical storage
3. 立即把结果值写回 guest `rd`

在这个基础上，只额外记录一条最小 metadata：

- “当前 pending producer 是 add-style”
- “它已经 materialize 了 canonical raw flags”
- “它留下的 live host `CF` 可以被相邻 plain `ADC` 直接消费”

到 consumer 侧时，不再重做 producer 的 add，也不再新增一条“两输出 fused op”。
而是直接复用现有的 carry-in arithmetic emission：

- `a64_emit_addcio_i64()`
- `a64_emit_addcio_i32()`

也就是 plain host `adc`。

### 为什么这条路更适合 phase 2

相比“延迟 producer，到 consumer 再一次性发两输出 fused op”，这条路有 3 个好处：

1. producer 的结果值已经自然 materialize
   所以 consumer 不需要额外负责 producer 结果写回。
2. 不会把 producer 的 add 重做第二遍
   避免为了保 flags 再平白多出一次 arithmetic 成本。
3. 后端几乎不需要新增机制
   因为 `addcio` 已经存在，缺的主要是前端 metadata 和匹配条件。

这也是为什么它更像 `1.5`：

- 它不是纯粹的一次性特例
- 但也没有重构成完整 framework

## 备选方案与取舍

### 方案 1：完整做成通用 pending-cc producer framework

优点：

- 如果马上连续做很多扩展，长期结构最整齐

缺点：

- 现在需要先决定太多还没被需求证实的抽象维度
- 很容易把当前稳定路径一起搅动
- phase 2 的核心问题其实还没大到必须靠全框架重写来解决

这一步不采用。

### 方案 2：延迟 `ADDS rd` producer，到 consumer 发两输出 fused op

优点：

- 和 phase 1 的 “producer defer + consumer consume” 形态最像

缺点：

- 要同时保 producer 结果和 consumer 结果
- 要么引入两输出 op，要么在 consumer 侧做额外 glue
- 很容易把 producer 的 add 算两遍

这一步不采用。

### 方案 3：producer 维持现状，consumer 只靠“猜” host `CF` 还活着

优点：

- 表面改动最小

缺点：

- 如果不把“live carry 可直用”记成显式 metadata，就会让约束过于隐式
- 后续扩展时难以统一 reasoning

所以只取它的“继续复用 direct producer”这部分，不取它的“完全不显式建模”。

## 架构设计

### Producer 路径

phase 2 的 producer 落点仍然是：

- `do_addsub_reg()`

命中条件：

- `setflags == true`
- `sub_op == false`
- `rd != 31`
- 下一条指令是相邻 plain register-form `ADC`
- host 是 x86

命中后：

- 仍然走 `gen_add_CC(..., allow_direct = true)`
- 不延迟 producer result materialization
- producer 结束后，把 pending metadata 标成：
  - add-style producer
  - adjacent-only
  - live carry 可供下一条 `ADC` 直接消费

这一步建议在现有 `a64_cmp_pending_*` 上只增加最少字段，例如：

- `a64_cmp_pending_live_carry`
- 或者一个更一般的 producer-kind / producer-mode 标记

但不在本步重命名整套 `cmp_pending` 字段。

### Consumer 路径

consumer 继续落在：

- `do_adc_sbc()`

在 plain `ADC` 分支优先尝试：

- `a64_try_emit_x86_add_adc(...)`

但这次 helper 内部区分两种 producer：

1. compare-like add producer（phase 1 现有 `CMN / ADDS xzr`）
   继续走当前 fused `add + capture + adc`
2. result-preserving add producer（本步新增 `ADDS rd`）
   不再重做 producer add，而是直接发：
   - `a64_emit_addcio_i64()`
   - 或 `a64_emit_addcio_i32()`

这样 consumer 直接吃 live host `CF`，同时 canonical flags 仍然保持为 producer flags。

### Flags / 状态模型

phase 2 不引入新的 canonical flags state。

producer 命中后，consumer 之前的状态仍然是：

- `cpu_x86_raw_flags`：producer raw flags
- `cpu_x86_cc_op`：`A64_X86_CC_ADD32/ADD64`
- `cpu_x86_flags_valid`：raw

consumer 命中 direct path 后：

- guest 可见 flags 仍然语义上来自 producer
- host 物理 flags 会被 consumer `adc` 覆盖
- 但后续 architectural flags 读取仍然通过 canonical raw state 看到 producer NZCV

这和 phase 1 的核心语义是一致的。

## 数据流

### hit path

1. translator 识别 `ADDS rd, ...`
2. 识别下一条是相邻 plain `ADC`
3. producer 正常走 direct `gen_add_CC`
4. producer 结束时记录“live carry 可直用”的 pending metadata
5. `ADC` 看到相邻 pending producer
6. consumer 直接发 host `adc`（`addcio`），跳过 canonical carry decode

### miss path

1. producer 继续走现有 `gen_add_CC`
2. consumer 继续走现有 `gen_adc`

任何 miss 都不能影响当前 phase 1 已经稳定的 `CMN/ADDS xzr -> ADC` 路径。

## 安全边界

只要下列任一条件不满足，就直接回退到现有路径：

- 非 x86 host
- 不是相邻 same-TB 匹配
- producer 不是 register-form `ADDS rd`
- producer 没有走 direct raw-flags producer 路径
- consumer 不是 plain register-form `ADC`
- pending producer 不是 add-style

另外，这一步要特别防止两种 producer 模式互相串线：

- compare-like producer（phase 1）
- result-preserving producer（phase 2）

helper 内部必须显式区分。

## 测试

### TDD 红灯入口

这一步最合适的红灯入口是 codegen test，而不是语义 test。

原因是：

- 当前 generic lowering 在语义上本来就是正确的
- 真正缺的是“consumer 还在 decode carry，没有吃 live `CF`”

所以红灯应该是：

- 相邻 `ADDS rd -> ADC` 的 host block 仍然带着 carry-decode 链

### 需要新增 / 扩展的测试

1. 扩展 `tests/tcg/aarch64/adc-sbc-host-direct.S`
   新增相邻 `ADDS rd -> ADC` 的 64-bit / 32-bit case
2. 扩展 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
   检查命中 block：
   - 有 producer `add`
   - 有 consumer `adc`
   - consumer 前没有 canonical carry decode 链
3. 扩展 `tests/tcg/aarch64/nzcv-status4.S`
   新增：
   - 64-bit adjacent `ADDS rd -> ADC`
   - 32-bit adjacent `ADDS rd -> ADC`
   用来守护：
   - producer 结果值
   - consumer 结果值
   - producer NZCV 保持正确
4. 扩展 dedicated benchmark
   需要真正命中这次优化的新 mode，例如：
   - `addsadc64`
   - `addsadc32`

### 必跑回归

- `ninja -C build-aarch64-linux-user qemu-aarch64`
- `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ... adc-sbc-host-direct`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`

## perf 验证

correctness 全绿后，继续沿用同一套 isolated A/B：

- 同一棵树
- 同一二进制
- 只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`

但这次要优先看新增的 dedicated mode：

- `addsadc64`
- `addsadc32`

控制项保留：

- `cmnadc64`
- `cmnadc32`
- `adc64`
- `adc32`

## 后续如何自然过渡到“3”

这份设计本身就是按“以后会继续扩”来留接口的。

如果后面继续做：

- `SUBS rd -> SBC`
- immediate / ext producer
- 更多 arithmetic direct-through

那真正值得做的，就是把 phase 1 和 phase 2 里已经被证明必要的维度，收敛成完整 framework：

- producer kind
- producer 是否已 materialize canonical flags
- live carry / borrow 是否可供相邻 consumer 直用
- 是否保结果值

到那时再做 `3`，就不是猜抽象，而是从两代真实实现里提炼框架。

## 预计修改文件

- 修改：`target/arm/tcg/translate.h`
- 修改：`target/arm/tcg/translate-a64.c`
- 修改：`tests/tcg/aarch64/adc-sbc-host-direct.S`
- 修改：`tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
- 修改：`tests/tcg/aarch64/nzcv-status4.S`
- 修改：`tests/tcg/aarch64/adcsbc-bench.c`
- 修改：`tests/tcg/aarch64/adcsbc-bench.out`
- 修改：`a64_tcg_cmpjcc_perf_results.md`
- 修改：`codex_a64_x86_status4_cmpjcc_plan.md`
