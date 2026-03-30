# `SUBS rd -> plain SBC` 直连 consumer 设计（1.5 方案）

**日期：** 2026-03-30

**状态：** 已确认，可进入实现计划

## 目标

在现有 x86 host direct-carry / borrow 工作基础上，继续把 sub-side 直通往前扩一格：

- 让 same-TB、相邻的 `SUBS rd, ...` producer
- 可以把 live host `CF`（borrow）
- 直接喂给下一条 plain `SBC`

同时还要满足：

- producer 的结果值仍然正确写回 `rd`
- guest 可见的 NZCV 仍然保持为 producer 的 flags
- consumer 前不再从 canonical flags 里 decode carry / borrow

这一步只覆盖：

- AArch64 guest on x86 host
- same-TB 相邻 producer / consumer
- register-form `SUBS rd, rn, rm{, shift}`
- plain non-setflags `SBC`

## 为什么继续采用 `1.5` 方案

我们已经确认后续扩展会继续沿 arithmetic producer / consumer 这条线推进：

- `ADDS rd -> ADC`
- `SUBS rd -> SBC`
- 更宽的 immediate / ext producer

而且 `ADDS rd -> ADC` 已经证明：

- 继续复用现有 direct producer
- 只补最小 metadata
- consumer 直接吃 live host carry chain

这条路线是能稳定落地并拿到正收益的。

对 `SUBS rd -> SBC` 来说，这条路反而更自然：

- x86 `sub` 产出的 `CF` 就是 borrow
- x86 `sbb` 直接消费的也是 borrow-in
- AArch64 `SBC` 语义是 `rn - rm - !C`
- 而 `SUBS` 后的 AArch64 `C = !borrow`

所以：

- `SUBS` producer 留下的 live host `CF=borrow`
- 与后续 plain host `sbb`
- 在语义上天然对齐

## 非目标

这一步不做：

- `SUBS xzr -> SBC` 以外更宽的 compare-like 扩展
- immediate-form `SUBS`
- extended-form `SUBS`
- 带 gap 的匹配
- cross-TB 匹配
- `SBCS`
- 通用化重命名整个 `a64_cmp_pending` 体系
- 新的“大一统 fused arithmetic producer/consumer backend framework”

## 选定方案

### 总体思路

producer 不做 defer。

`SUBS rd` 继续复用当前已经存在的 direct producer 路径：

- `gen_sub_CC(..., allow_direct = true)`

也就是：

1. 先直接算出 producer 结果值
2. 直接 capture producer raw flags 到 canonical storage
3. 立即把结果值写回 guest `rd`

在这个基础上，只额外记录：

- 当前 pending producer 是 sub-style
- 它已经 materialize 了 canonical raw flags
- 它留下的 live host `CF=borrow` 可以被相邻 plain `SBC` 直接消费

到 consumer 侧时：

- 不再重做 producer 的 `sub`
- 不再从 canonical flags decode borrow
- 直接复用已有 host `sbb` emission

也就是 plain host `sbb`。

### 为什么这一步甚至比 `ADDS -> ADC` 更顺

`ADDS -> ADC` 虽然也是自然的 carry chain，但还需要更明确地区分：

- add-style producer
- compare-like add producer

而 `SUBS -> SBC` 这一步在 host 语义上的对齐更直接：

- `sub` 写 `CF=borrow`
- `sbb` 吃 `CF=borrow`

所以 producer / consumer 之间不需要插额外的 borrow seed glue。

## 备选方案与取舍

### 方案 1：完整做成通用 pending-cc producer framework

优点：

- 如果马上连续做很多扩展，长期结构最整齐

缺点：

- 现在仍然要提前决定太多还没被真实需求证明的抽象维度
- 会把已经稳定的 add / cmp 路径一起搅动

这一步不采用。

### 方案 2：延迟 `SUBS rd` producer，到 consumer 再一次性发 fused op

优点：

- 形式上更像 step 16 的 compare-like `CMP -> SBC`

缺点：

- 要同时保 producer 结果和 consumer 结果
- 很容易把 producer 的 `sub` 重做第二遍

这一步不采用。

### 方案 3：producer 维持现状，consumer 只靠隐式假设 host `CF` 仍然活着

优点：

- 改动表面最小

缺点：

- 约束不显式
- 后续扩展时不好统一 reasoning

所以这一步仍然采用显式 pending metadata，而不是完全靠隐式假设。

## 架构设计

### Producer 路径

phase 2 的 producer 仍然落在：

- `do_addsub_reg()`

命中条件：

- `setflags == true`
- `sub_op == true`
- `rd != 31`
- 下一条指令是相邻 plain register-form `SBC`
- host 是 x86

命中后：

- 仍然走 `gen_sub_CC(..., allow_direct = true)`
- 不延迟 producer result materialization
- producer 结束后记录 pending metadata

这里和 `ADDS rd -> ADC` 不同的一点是：

- 当前已经存在的 `a64_cmp_pending_materialized`
- 配合 `A64_X86_CC_SUB32/64`
- 理论上已经足够区分
  - compare-like sub producer（step 16）
  - result-preserving sub producer（本步）

因此这一步优先复用已有 metadata，不额外新开字段。

### Consumer 路径

consumer 继续落在：

- `do_adc_sbc()`

在 plain `SBC` 分支优先尝试：

- `a64_try_emit_x86_cmp_sbc(...)`

但 helper 内部要显式区分两种 producer：

1. compare-like sub producer（现有 `CMP / SUBS xzr`）
   - 继续走当前 fused `cmp + capture + sbb`
2. result-preserving sub producer（本步新增 `SUBS rd`）
   - 不再重做 producer `cmp/sub`
   - 直接发 plain host `sbb`

这样 consumer 直接吃 live host borrow chain，同时 canonical flags 仍然保持为 producer flags。

### Flags / 状态模型

这一步不引入新的 canonical flags state。

producer 命中后，consumer 之前的状态仍然是：

- `cpu_x86_raw_flags`：producer raw flags
- `cpu_x86_cc_op`：`A64_X86_CC_SUB32/64`
- `cpu_x86_flags_valid`：raw

consumer 命中 direct path 后：

- guest 可见 flags 仍然语义上来自 producer
- host 物理 flags 会被 consumer `sbb` 覆盖
- 但后续 architectural flags 读取仍然通过 canonical raw state 看到 producer NZCV

## 数据流

### hit path

1. translator 识别 `SUBS rd, ...`
2. 识别下一条是相邻 plain `SBC`
3. producer 正常走 direct `gen_sub_CC`
4. producer 结束时记录“live borrow 可直用”的 pending metadata
5. `SBC` 看到相邻 pending producer
6. consumer 直接发 host `sbb`，跳过 canonical borrow decode

### miss path

1. producer 继续走现有 `gen_sub_CC`
2. consumer 继续走现有 `gen_sbc`

任何 miss 都不能影响当前 step 16 已经稳定的 `CMP / SUBS(xzr) -> SBC` 路径。

## 安全边界

只要下列任一条件不满足，就直接回退到现有路径：

- 非 x86 host
- 不是相邻 same-TB 匹配
- producer 不是 register-form `SUBS rd`
- producer 没有走 direct raw-flags producer 路径
- consumer 不是 plain register-form `SBC`
- pending producer 不是 sub-style

另外，这一步要特别防止两种 producer 模式互相串线：

- compare-like producer（step 16）
- result-preserving producer（本步）

helper 内部必须显式区分。

## 开关与隔离

为了能和 step 16 分开做 isolated A/B，这一步需要独立开关：

- `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1`

这样：

- `QEMU_A64_DISABLE_CMP_SBC_DIRECT=1`
  仍然只控制 compare-like `CMP / SUBS(xzr) -> SBC`
- `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1`
  只控制本步 `SUBS rd -> SBC`

## 测试

### TDD 红灯入口

这一步最合适的红灯入口仍然是 codegen test，而不是语义 test。

建议新增两组 guest 场景：

- `SUBS64 rd -> SBC`
- `SUBS32 rd -> SBC`

预期 host block：

- 有 producer `sub`
- 有 consumer `sbb`
- consumer 前不再出现：
  - `shr/and/setcc` 这类 carry decode
  - 为 borrow seed 服务的额外 `sub 0, borrow_in`
  - 重做 producer compare 的 `cmp`

### 语义 guard

`nzcv-status4` 需要补两条：

- `0x98`：adjacent `SUBS64 rd + plain SBC`
- `0x99`：adjacent `SUBS32 rd + plain SBC`

同时验证：

- producer 结果值
- consumer 结果值
- producer NZCV

### benchmark

需要补 dedicated mode：

- `subsbc64`
- `subsbc32`

并沿用 step 18 同样的方法做 same-binary isolated A/B，只切：

- `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1`

## 预期收益

如果实现正确，这一步应当：

- 删除 consumer 前的 borrow decode 热路径
- 避免重做 producer compare / sub
- 在 dedicated `SUBS -> SBC` 模式上拿到正收益

同时，控制项应保持基本持平：

- `cmp -> sbc`
- `sbc64/sbc32`
- `adc64/adc32`

## 下一步

如果这一步 correctness 和 perf 都站稳，后续可以继续看：

- immediate / ext producer
- 更中性的 pending-producer metadata 收敛
- 或者把 add/sub 两边共同需要的状态再抽一小层
