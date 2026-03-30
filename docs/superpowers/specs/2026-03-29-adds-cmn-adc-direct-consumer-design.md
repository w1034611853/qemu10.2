# `ADDS/CMN -> plain ADC` 直连 consumer 设计

**日期：** 2026-03-29

**状态：** 已确认，可进入 phase 1 实现

## 目标

在现有 x86 host direct-carry 工作基础上，继续扩一条最窄的新链路：
让 same-TB、相邻的 compare-like add producer，可以直接喂给 plain `ADC`
consumer，而不需要先从 canonical flags 里把 carry 再 decode 出来。

phase 1 只覆盖：

- AArch64 guest on x86 host
- same-TB 相邻 producer / consumer
- compare-like add producer 的 register form：
  - `CMN`
  - `ADDS xzr, ...`
- plain non-setflags `ADC`

## 为什么先收这个范围

刚做完的 `CMP/SUBS(xzr) -> plain SBC` direct consumer 这一步，已经用
isolated A/B 证明是正收益。add 侧最对应、风险也最低的切入点就是
same-TB adjacent compare-like producer：

- AArch64 add-family carry 语义与 x86 `CF` 天然对齐
- producer 结果值被丢弃，所以只需要保住 flags
- 相比直接上 `ADDS rd, ... -> ADC`，这一步复杂度和风险都更低

这个 phase 1 是刻意收窄的安全切片，后面可以自然扩到 phase 2。

## 非目标

phase 1 不做：

- `ADDS rd, ... -> ADC` 这种还需要保住 producer 结果值的形式
- immediate form `ADDS/CMN`
- extended form `ADDS/CMN`
- 带 gap 的匹配
- cross-TB 匹配
- `ADCS`
- 非 x86 host

## 选定方案

复用现在 `CMP/SUBS(xzr) -> SBC` 这条链路使用的 pending-producer 模式，
但这次记录 add-style producer（`A64_X86_CC_ADD32/ADD64`），并且只在
plain `ADC` consumer 侧消费。

命中时的流程：

1. translator 识别到相邻的 compare-like add producer
2. 暂缓走原来的 producer materialization
3. 到 plain `ADC` consumer 时，发一条融合后的 host 序列：
   - 只为了 flags 先计算 producer 的 `add`
   - 把 producer 的 raw flags capture 到 canonical storage
   - 紧接着让 consumer 直接用 live `CF` 执行 host `adc`

这样能同时保证：

- guest 可见的 NZCV 仍然来自 producer
- plain `ADC` 前面那条 canonical carry decode 链被删掉

## 考虑过的替代方案

### 方案 1：直接扩大到 `ADDS rd, ... -> ADC`

优点：

- 覆盖面更大

缺点：

- producer 结果值需要和 live `CF` 一起保住
- 后端序列和寄存器约束会立刻变复杂

phase 1 不采用。

### 方案 2：继续用 canonical carry decode，只加 translator hint

优点：

- 改动最小

缺点：

- 吃不到这一步的主要性能收益
- 也无法验证 add 侧 live-carry direct-consumer 模式

不采用。

## 架构设计

### Producer 识别逻辑

增加一个很窄的相邻 plain `ADC` 识别器：

- `a64_insn_is_plain_adc_reg()`
- `a64_find_adjacent_plain_adc()`
- 环境变量开关：
  - `QEMU_A64_DISABLE_ADD_ADC_DIRECT`

phase 1 的 producer 落点：

- register-form `do_addsub_reg()`
- 只在以下条件同时满足时命中：
  - `setflags == true`
  - `sub_op == false`
  - `rd == 31`
  - 下一条指令是 plain register-form `ADC`

命中后，通过现有 pending-producer 状态记录：

- `cc_op = A64_X86_CC_ADD32/ADD64`
- `gap_insns = 0`

phase 1 不加入 immediate / ext 支持。

### Consumer 降低路径

增加一条 add-side 版本的 fused direct-consumer 路径，和现在的
cmp->sbb 路径并列：

- translator helper：
  - `a64_try_emit_x86_add_adc(...)`
- backend 自定义 op：
  - 名字可沿用当前风格，例如
    `x86_add_adc_capture_add_rawflags`

这条 fused host 序列需要满足的语义：

1. 先把最终 `ADC` 的目标寄存器当 scratch 使用
2. 在这个 scratch 里做 producer 的 `add`
3. 把 producer 的 raw flags capture 到 `env->x86_raw_flags`
4. 再把 consumer 的 lhs 重新放回目标寄存器
5. 用 consumer 的 rhs 执行 host `adc`

关键性质：

- canonical raw flags 表示的是 producer add
- live x86 `CF` 直接流到 consumer `adc`
- consumer 不需要先从 canonical state decode carry

### Flags / 状态模型

不引入新的 canonical flags state。

命中后，consumer 之后的状态仍然是：

- `cpu_x86_raw_flags` 保存 producer raw flags
- `cpu_x86_cc_op` 为 `A64_X86_CC_ADD32/ADD64`
- flags-valid 状态仍然是 raw

这样后面的 consumer 和 fallback 路径都不用改语义。

## 数据流

translator hit path：

1. 识别 `CMN` / `ADDS xzr` 是 compare-like add producer
2. 识别下一条是 plain `ADC`
3. producer 不走原来的 split/raw lowering，而是记成 pending state
4. `ADC` 通过 fused host op 直接消费这个 pending add producer
5. 后续 consumer 仍然通过 canonical raw flags 看到 producer 的 NZCV

miss path：

1. producer 继续走现有 lowering
2. plain `ADC` 继续走现有 lowering

## 安全性与 fallback 边界

只要下面任一条件不满足，就直接退回现有行为：

- x86 host
- 指令是相邻匹配
- same page / same TB
- producer `rd == 31`
- consumer 是 plain register-form `ADC`
- producer `cc_op` 是 add-style

phase 1 不能顺手把匹配范围偷偷放宽。

## 测试

### TDD 入口

先写 codegen test，看它 fail，再做实现。

### 需要新增 / 扩展的测试

1. 扩展 `tests/tcg/aarch64/adc-sbc-host-direct.S`
   加一个相邻 `CMN/ADDS xzr -> ADC` 形态。
2. 扩展 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
   断言命中的 block 里有：
   - host `add`
   - host `adc`
   - consumer 前面没有 carry-decode 链
3. 扩展 `tests/tcg/aarch64/nzcv-status4.S`
   至少加入：
   - 64-bit adjacent `CMN -> ADC`
   - 32-bit adjacent `CMN -> ADC`
   这两组都要验证：
   - consumer 结果值正确
   - producer NZCV 被正确保留

### 必跑回归

- `ninja -C build-aarch64-linux-user qemu-aarch64`
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adc-sbc-host-direct-codegen`
- `build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`
- `build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`
- `build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`

### 后续 perf 验证

correctness 全绿后，沿用和 SBC 那一步相同的 isolated A/B 方法：

- 同一棵树
- 同一二进制
- 只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`

优先关注：

- `adc64`
- `adcsbc64`
- `adc32`
- `adcsbc32`

控制项：

- `sbc64`

## 第二阶段扩展路径

phase 1 是刻意设计成 `ADDS rd, ... -> ADC` 的台阶。

phase 2 可以直接复用的部分：

- 相邻 plain `ADC` 识别器
- 环境变量开关
- add-style pending-producer 分类
- add-side fused direct-consumer 后端形状
- 测试和 perf harness

phase 2 还需要单独解决的问题：

- 既保住 producer 算术结果，又复用 live `CF`
- fused host 序列下更紧的寄存器分配约束
- 比 compare-like add 更宽的 producer 覆盖

## 预计会修改的文件

- 修改：`target/arm/tcg/translate-a64.c`
- 修改：`tcg/i386/tcg-target-opc.h.inc`
- 修改：`tcg/i386/tcg-target-con-set.h`
- 修改：`tcg/i386/tcg-target.c.inc`
- 修改：`tcg/tcg.c`
- 修改：`tcg/optimize.c`
- 修改：`tests/tcg/aarch64/adc-sbc-host-direct.S`
- 修改：`tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
- 修改：`tests/tcg/aarch64/nzcv-status4.S`

## 这份 spec 已解决的开放问题

可以，phase 1 本身就是一个干净的 phase 2 基础。

正确的取舍是把 phase 1 严格限制在 compare-like add producer 上，这样
phase 2 只需要解决“producer 结果值保留”这个新增问题，而不用同时再去
拆匹配逻辑和 state model。
