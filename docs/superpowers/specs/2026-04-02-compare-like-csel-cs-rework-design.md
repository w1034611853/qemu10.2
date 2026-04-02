# Compare-like CSEL/CS* Rework Design

**日期：** 2026-04-02

**状态：** 草案，基于已确认的 `531.deepsjeng_r test` 回归定位

## 目标

重新设计并恢复下列路径：

- compare-like producer -> `CSEL`
- compare-like producer -> `CSINC`
- compare-like producer -> `CSINV`
- compare-like producer -> `CSNEG`
- compare-like producer -> `CSET`
- compare-like producer -> `CSETM`

这里的 compare-like producer 指：

- `CMP`
- `CMN`
- `SUBS xzr,...`
- `ADDS xzr,...`

目标不是恢复到“峰值 feature worktree 状态”，而是恢复到一个
**能够通过 focused checker + SPEC `531.deepsjeng_r test` closure 的稳定版本**。

## 当前状态

主分支当前已经暂时把 compare-like `CSEL/CS*` 强制回退到 fallback。

保留状态：

- compare-like `CCMP/CCMN`
- compare-like `FCSEL`
- compare-like `FCCMP`
- materialized `ADDS/SUBS rd -> CSEL/CCMP/FCSEL/FCCMP`
- materialized `ADCS/SBCS rd -> CSEL/CCMP/FCSEL/FCCMP`
- `B.cond` 线

也就是说，当前要重做的不是整个 compare-like non-branch family，而只是
`CSEL/CS*` 这一支。

## 已确认问题

`531.deepsjeng_r test` 的 first bad commit 已经被 bisect 到：

- `6653c87c86` `aarch64: extend lazy compare B.cond add-side coverage`

但当前主分支上的 active regression，进一步收缩后表明：

- 不是 `carry -> B.cond`
- 不是整条 branch line
- 不是 compare-like `CCMP/FCSEL/FCCMP`
- 是 compare-like `CSEL/CS*`

更具体地说：

- 只要关闭 compare-like `CSEL/CS*`，`531.deepsjeng_r test` 恢复
- 保留 compare-like `CCMP/FCSEL/FCCMP` 不会重新引入该回归
- 仅仅对 compare-like `CSEL` producer operands 做 snapshot，**不足以**
  修复该问题

所以现在不能再假设根因只是 operand alias。

## 当前实现为什么不稳

当前 `trans_CSEL()` 的 compare-like fast path是：

1. consumer 通过 `a64_try_peek_cmp_cond_bool_i32()` 读取 `pending_cc`
2. 把条件计算成 `cond32`
3. 设置：
   - `s->a64_pending_cc.keep = true`
4. 让 compare-like `pending_cc` 继续活到后续 consumer

这个模型的问题是：

- `CSEL/CS*` 自己不写 flags
- 但它们也不是像 `B.cond` / `CCMP` 那样的 terminal consumer
- 当前实现把 compare-like producer 长时间保留成 `pending_cc`
  的“活状态”，而不是在 `CSEL/CS*` 用完条件后转成稳定 flags 表示

从行为上看，这个“peek + keep alive”模型会在真实 workload 中让后续
flags 可见性和 producer 生命周期发生冲突。

## 非目标

这次 rework 不做：

- 重开 compare-like `B.cond`
- 修改 `CCMP/FCSEL/FCCMP` 当前实现
- 修改 materialized producer 家族
- 设计全新的统一 flags scheduler
- cross-TB lazy compare
- 修复所有 future multi-consumer chaining 场景

这次只解决：

- compare-like `CSEL/CS*` 的 correctness

## 候选方案

### 方案 1：继续使用 `peek + keep alive`，修补 snapshot / alias

思路：

- 继续让 `CSEL/CS*` 读取 compare-like `pending_cc`
- 通过 snapshot operands、调整 keep/end、或额外 invalidation 来修补

优点：

- 最小改动
- 看起来能保留“非 terminal consumer 之后继续复用 pending compare”这个收益

缺点：

- 现有调试已经表明，仅 operand snapshot 不足以修复
- 生命周期问题比简单 alias 更深
- 风险高，继续打补丁很容易回到“SPEC 过了、别的 workload 又坏”的状态

这次不选。

### 方案 2：`CSEL/CS*` 消费 compare-like pending 后，立即 retire 到 split flags

思路：

1. `CSEL/CS*` 仍然可以直接用 compare-like producer 计算条件
2. 但一旦 consumer 读完条件，就不再保留 compare-like `pending_cc`
3. 立刻把原 producer 对应的 NZCV materialize 成 split flags：
   - `cpu_NF`
   - `cpu_ZF`
   - `cpu_CF`
   - `cpu_VF`
4. 清掉 compare-like `pending_cc`
5. 后续 flags user 全部走稳定 flags 表示

优点：

- `CSEL/CS*` 仍然吃到 direct 条件收益
- 后续 flags 生命周期不再依赖 fragile 的 compare-like pending 继续存活
- 语义更接近 “consumer 不改 flags，但 flags 仍然可读”

缺点：

- 相比原来的“继续保留 pending compare”，会牺牲后续多 consumer 链式收益
- 需要给 compare-like producer 做一次 consumer-after-peek 的 split flags 回写

这次采用。

### 方案 3：compare-like `CSEL/CS*` 永久 fallback

优点：

- 最安全

缺点：

- 直接放弃这条优化
- 已经有完整 focused harness，不值得永久放弃

不采用，除非方案 2 失败。

## 选定方案

### 核心原则

compare-like `CSEL/CS*` 采用：

- **direct condition**
- **stable post-consume flags**

具体来说：

- consumer 仍然从 compare-like producer 直接得到条件布尔值
- 但 consumer 不是“peek and keep”
- 而是“consume for condition, then retire producer into split flags”

### 生命周期模型

#### Producer record

与当前 compare-like producer 记录保持一致：

- `lhs`
- `rhs`
- `cc_op`
- `kind == REWINDABLE_CMP`
- `gap_insns`

#### Consumer read

`trans_CSEL()` 命中 compare-like fast path时：

- 先从 `pending_cc` 计算 condition bool
- 然后**不设置** `keep = true`
- 而是执行一次显式 retire

#### Retire to split flags

新 retire helper 负责：

1. 从 compare-like `lhs/rhs` 重新计算 producer 的 NZCV
2. 写入：
   - `cpu_NF`
   - `cpu_ZF`
   - `cpu_CF`
   - `cpu_VF`
3. 设置：
   - `a64_note_flags_split(s)`
4. 让 raw flags 失效
5. 清理 compare-like `pending_cc`

这样之后：

- 后续 `ADC/SBC`
- 后续 `MRS NZCV`
- 后续 `B.cond`
- 后续其它 flags consumer

看到的都是稳定、明确的 split flags，而不是继续活着的 pending compare。

### 为什么只对 compare-like `CSEL/CS*` 这么做

因为：

- `CCMP/CCMN` 是 terminal flags producer，本来就更像 consume
- `FCSEL/FCCMP` 当前 closure 没证明有 live bug
- 当前 regression 只定位到了 compare-like `CSEL/CS*`

所以这次 rework 的范围应该精确，只改最小问题面。

## 需要覆盖的测试

### Focused regression

需要把 compare-like `CSEL/CS*` 从“期待 pending peek”改成：

- 期待语义正确
- 期待 compare-like direct branch line不介入
- 期待 consumer 后 flags 仍然正确可读

重点要新增一组“consumer 后继续读 flags”的用例，形状类似：

- `CMP -> gap -> CSEL -> B.eq`
- `CMP -> gap -> CSET -> ADC`
- `CMN -> gap -> CSINC -> MRS NZCV`

这些才是这次 rework 真正要证明的点。

### Workload closure

至少要复跑：

- `531.deepsjeng_r test`
- SPEC 7 个 `test size`
- `adcsbc-bench`
- `cmpstress-o3`
- `nzcv-status4`

## 风险

主要风险有两个：

1. retire 到 split flags 的 helper 可能在 32/64 位、add/sub family 上算错 NZCV
2. `CSEL/CS*` consumer 后的 flags 可见性虽然稳定了，但可能让一部分
   focused direct-path checker 需要重新定义预期

这两个风险都比继续保留 compare-like pending 活状态要可控。

## 建议执行顺序

1. 先写 focused failing regression，特别是 consumer 后继续读 flags
2. 再实现 compare-like `CSEL/CS*` 的 retire-to-split helper
3. 再恢复 `lazy_condsel_cmp`
4. 最后跑 workload closure

## 成功标准

这次 rework 完成的标准是：

- compare-like `CSEL/CS*` 重新启用
- `cmp-csel-gap-host-direct` 重新成为正向 direct-path checker
- `531.deepsjeng_r test` 恢复通过
- SPEC 7 个 `test size` 结果回到：
  - 只剩 `500.perlbench_r` 的已知 nested-perl 问题
- 不回退 `CCMP/FCSEL/FCCMP` 当前已保留的 compare-like 功能
